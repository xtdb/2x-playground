/*
  Based on https://www2.cs.arizona.edu/~rts/tdbbook.pdf p301

  Information is the key asset of many companies. Nykredit, a major Danish
  mortgage bank, is a good example. In 1989, the Danish legislature changed the
  Mortgage Credit Act to allow mortgage providers to market loans directly to
  customers and through real estate agents

  One of the challenges was achieving high data quality on the customers and
  their loans, while expanding the traditional focus to also include customer
  support. Managers needed access to up-to-date data to set benchmarks and
  identify problems in various areas of the business. The sheer volume of the
  data, nine million loans to eight million customers concerning seven million
  properties, demands that eliminating errors in the data must be highly
  efficient

  It was mandated that changes to critical tables be tracked. This implies that
  the tables have transaction-time support. As these tables also model changes
  in reality, they require valid-time support. The result is termed a bitemporal
  table, reflecting these two aspects of underlying temporal support. With such
  tables, IT personnel can rst determine when the erroneous data was stored (a
  transaction time), roll back the table to that point, and look at the
  valid-time history. They can then determine what the correct valid-time
  history should be. At that point, they can tell the customer service person
  what needs to be changed, or if the error was in the processing of a user
  transaction, they may update the database manually.
  */

/* NOTE:
   - transation-time = system-time, valid-time=application-time
   - these source examples were written with example transactions during the year 1998
   - they assumed SQL-92 features and usage patterns
/*

CREATE TABLE Prop_Owner (
  customer_number INT,
  property_number INT,
  VT_Begin DATE,
  VT_End DATE,
  TT_Start TIMESTAMP,
  TT_Stop TIMESTAMP)

CREATE TABLE Customer (
  name CHAR,
  VT_Begin DATE,
  VT_End DATE,
  TT_Start TIMESTAMP,
  TT_Stop TIMESTAMP)

CREATE TABLE Property (
  property_number INT,
  address CHAR,
  property_type INT,
  estimated_value INT,
  VT_Begin DATE,
  VT_End DATE,
  TT_Start TIMESTAMP,
  TT_Stop TIMESTAMP)
  */

/*
  -- Stating that a key on a bitemporal table is valid-time sequenced requires an assertion.


  -- We will apply this assertion at the current transaction time; that only
     current modications are permitted in transaction time will ensure that it
     holds over all transaction-time states.
  -- property number is a (valid-time sequenced, transaction-time sequenced)
     primary key for Prop Owner:

  CREATE ASSERTION P_O_seq_primary_key
  CHECK (NOT EXISTS (SELECT *
  FROM Prop_Owner AS P1
  WHERE property_number IS NULL
  OR 1 < (SELECT COUNT(customer_number)
  FROM Prop_Owner AS P2
  WHERE P1.property_number = P2.property_number
  AND P1.VT_Begin < P2.VT_End
  AND P2.VT_Begin < P1.VT_End
  AND P1.TT_Stop = DATE "9999-12-31"
  AND P2.TT_Stop = DATE "9999-12-31"))

  -- While we're at it, we also include a nonsequenced valid-time assertion: that there
  are no gaps in the valid-time history. Specically, once a property is acquired by a
  customer, it remains associated with an owner (or sequence of owners) over its
  existence.
  -- Prop_Owner.property number defines a contiguous valid-time history:
  CREATE ASSERTION P_O_Contiguous_History
  CHECK (NOT EXISTS (SELECT *
  FROM Prop_Owner AS P, Prop_Owner AS P2
  WHERE P.VT_End < P2.VT_Begin
  AND P.property_number = P2.property_number
  AND P.TT_Stop = DATE "9999-12-31"
  AND P2.TT_Stop = DATE "9999-12-31"
  AND NOT EXISTS (
  SELECT *
  FROM Prop_Owner AS P3
  WHERE P3.property_number = P.property_number
  AND (((P3.VT_Begin <= P.VT_End)
  AND (P.VT_End < P3.VT_End))
  OR ((P3.VT_Begin < P2.VT_Begin)
  AND (P2.VT_Begin <= P3.VT_End)))
  AND P3.TT_Stop = DATE "9999-12-31"))
)
)
  ...
*/

-- [10.2] MODIFICATIONS

/*
  Let's follow the history, over both valid time and transaction time, of a at
  in Aalborg, at Skovvej 30 for the month of January 1998.

  Starting with Current Modifications (Inserts, Updates, Deletes)

  INSERT INTO Prop_Owner (customer_number, property_number, VT_Begin,
  VT_End, TT_Start, TT_Stop)
  VALUES (145, 7797, CURRENT_DATE,
  DATE "9999-12-31", CURRENT_TIMESTAMP, DATE "9999-12-31")
*/

SET application_time_defaults TO as_of_now;

-- for XTDB an explicit ID is needed, let's not complicate everything with UUIDs for now...

INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start)
VALUES (1, 145, 7797, DATE '1998-01-10');

-- Here we have but one region, associated with Eva Nielsen, that starts today
-- in transaction time and extends to until changed, and that begins also at
-- time 10 in valid time and extends to forever.
SELECT *
  FROM Prop_Owner AS x (id,
                        customer_number,
                        property_number,
                        application_time_start,
                        application_time_end,
                        system_time_start,
                        system_time_end);


-- Peter Olsen buys the flat; this legal transaction transfers ownership from Eva to him
INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start)
VALUES (1, 827, 7797, DATE '1998-01-15');

-- Observe the change
SELECT *
  FROM Prop_Owner AS x (id,
                        customer_number,
                        property_number,
                        application_time_start,
                        application_time_end,
                        system_time_start,
                        system_time_end);

-- See the full history
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- 3 entries? This is because the original validity region needed "splitting" into two parts, so that the later part could be overridden by the new value

/* This figure captures the evolving information content of the Prop Owner table
quite effectively. Consider a transaction time-slice, which returns the
valid-time history at a given transaction time. Such a time-slice can be
visualized as a vertical line intersecting the x-axis at the given time. At
transaction time 5 (January 5), the table has no record of the at being owned by
anyone. At transaction time 12, the table records that the flat was owned by Eva
from January 10 to forever. If we time-traveled back to January 12 and asked for
the history of the at, that would be the response. We thought then that Eva
owns the at, and that is what the Prop Owner table recorded then. At
transaction time 17 the table records that the at was owned by Eva from
January 10 to 15, at which time ownership transferred to Peter, who now owns
it to forever. And that is the history as best known (denoted by the
right-pointing arrows); it is what we think is true about the valid-time
history.
   */


-- We perform a current deletion when we find out that Peter has sold the property to someone else, with the mortgage handled by another mortgage company. From the bank's point of view, the property no longer exists as of (a valid time of) now.
DELETE
FROM Prop_Owner
     FOR PORTION OF APPLICATION_TIME FROM DATE '1998-01-20' TO END_OF_TIME
WHERE Prop_Owner.property_number = 7797;

-- current view is deleted, 0 rows
SELECT *
  FROM Prop_Owner
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- If we now request the valid-time history as best known, we will learn that Eva owned the at from January 10 to January 15, and Peter owned the at from January 15 to January 20. Note that all prior states are retained. We can still time-travel back to January 18 and request the valid-time history, which will state that on that day we thought that Peter still owned the at. In Figure 10.3, Peter's region was a rectangle. The current deletion has chopped off the top-right corner, so that the region is now L-shaped
-- The row associated with Peter in Figure 10.3 denotes a single rectangle. That rectangle must be converted into the two rectangles shown in Figure 10.7. We do so by terminating the existing row (by setting its transaction-stop time to now) and by inserting the portion still present, with a valid-end time of now.
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- [10.2.2] Sequenced Modifications - For bitemporal tables, the modication is sequenced only on valid time; the modication is always a current modification on transaction time, from now to until changed.

/*
INSERT INTO Prop_Owner (customer_number, property_number, VT_Begin,
                        VT_End, TT_Start, TT_Stop)
VALUES (145, 7797, DATE "1998-01-03",
        DATE "1998-01-10", CURRENT_TIMESTAMP, DATE "9999-12-31")*/


-- A sequenced insertion performed on January 23: Eva actually purchased the flat on January 3.
INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start, application_time_end)
VALUES (1, 145, 7797, DATE '1998-01-03', DATE '1998-01-10');

-- look again
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

/* This insertion is termed a retroactive modification, as the period of applicability is before the modification date
Sequenced (and nonsequenced) modifications can also be postactive, an example
being a promotion that will occur in the future (in valid time). (A valid-end time of "forever" is generally not considered a postactive modification; only the valid-start time is considered.) A sequenced modification might even be simultaneously
retroactive, postactive, and current, when its period of applicability starts in
  the past and extends into the future (e.g., a fixed-term assignment that
  started in the past and ends at a designated date in the future)
*/

-- We learn now 26 that Eva bought the flat not on January 10, as initially
-- thought, nor on January 3, as later corrected, but on January 5. This requires a
-- sequenced version of the following deletion:
DELETE
FROM Prop_Owner
FOR PORTION OF APPLICATION_TIME
FROM DATE '1998-01-03' TO DATE '1998-01-05';

-- look again
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- Updates
-- We next learn that Peter bought the flat on January 12, not January 15 as
-- previously thought. This requires a sequenced version of the following update.
-- This update requires a period of applicability of January 12 through 15,
-- setting the customer number to 145. Effectively, the ownership must be
-- transferred from Eva to Peter for those three days.
INSERT INTO Prop_Owner (id,
                        customer_number,
                        property_number,
                        application_time_start,
                        application_time_end)
VALUES (1, 145, 7797, DATE '1998-01-05', DATE '1998-01-12'),
       (1, 827, 7797, DATE '1998-01-12', DATE '1998-01-20');

-- look again
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- [10.2.3] Nonsequenced Modifications
-- We saw before that no mapping was required for nonsequenced modifications on
-- valid-time state tables; such statements treat the (valid) timestamps
-- identically to the other columns.
-- As an example, consider the modification "Delete all records with a valid-time
-- duration of exactly one week." This modifcation is clearly (valid-time)
-- nonsequenced: (1) it depends heavily on the representation, ooking for rows
-- with a particular kind of valid timestamp, (2) it does not apply on a per
-- instant basis, and (3) it mentions "records", that is, the recorded information,
-- rather than "reality".

-- Firstly let's identify the record(s):
SELECT *
  FROM Prop_Owner
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end)
 WHERE (x.application_time_end - x.application_time_start) = (DATE '1970-01-08' - DATE '1970-01-01');

-- Now we can delete:
DELETE
FROM Prop_Owner
FOR ALL APPLICATION_TIME AS x
WHERE (x.application_time_end - x.application_time_start) = (DATE '1970-01-08' - DATE '1970-01-01');
;; TODO 7 days issue?

-- look again
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- [10.3.1] Time-Slice Queries

-- A common query or view over the valid-time state table is to capture the
-- state of the enterprise at some point in the past (or future). This query is
-- termed a valid-time time-slice. For an auditable tracking log changes, we
-- might seek to reconstruct the state of the monitored table as of a date in
-- the past; this query is termed a transaction time-slice. As a bitemporal
-- table captures valid and transaction time, both time-slice variants are
-- appropriate on such tables.

-- Time-slices are useful also in understanding the information content of a
-- bitemporal table. A transaction time-slice of a bitem- poral table takes as
-- input a transaction-time instant and results in a valid-time state table that
-- was present in the database at that specified time.

-- A transaction time-slice query corresponds to a vertical slice in the time diagram.

-- A valid time-slice query corresponds to a horizontal slice as input a
-- valid-time instant and results in a transaction-time in the time diagram,
-- resulting in state table capturing when information concerning that specified
-- valid time was recorded in the database. A valid time-slice is a
-- transaction-time state table.

-- As mentioned earlier in this file, the transaction times in the examples are
-- historical and must be adapted, so we will use the 6 system_times returned by
-- the following query, which are unique to your instance
SELECT DISTINCT x.system_time_start
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME AS x
 ORDER BY x.system_time_start ASC;

-- e.g.
--        system_time_start
--  -------------------------------
--  "2022-09-11T15:13:53.846919Z"
--  "2022-09-11T15:14:00.376721Z"
--  "2022-09-11T15:14:06.605243Z"
--  "2022-09-11T15:14:11.991653Z"
--  "2022-09-11T15:14:17.017727Z"
--  "2022-09-11T15:14:42.592297Z"

-- These correspond 1:1 with the following entries:
--  DATE '1998-01-10'
--  DATE '1998-01-15'
--  DATE '1998-01-23'
--  DATE '1998-01-26'
--  DATE '1998-01-28'
--  DATE '1998-01-30'


-- Be sure to replace `T` with ` `, remove `Z`, and append `+00:00` when copying the literals for use with TIMESTAMP (TODO https://github.com/xtdb/core2/issues/431)

-- Give the history of owners of the flat at Skovvej 30 in Aalborg as of before our session began:
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-11 15:13:52+00:00'
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- Applying this time-slice results in an empty table, as no history was yet known about that property.

-- Taking a transaction time-slice as of January 14 results in a history with one entry:
-- i.e. use a TIMESTAMP between the 1st and 2nd entries (do this similarly again hereafter)
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-11 15:13:54+00:00'
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- On January 14, we thought that Eva was the current owner of that property. We
-- now know that Peter purchased the property on January 12, and that Eva never
-- owned the property at all on January 14, but that is 20-20 hindsight. The
-- information we had on January 14 indicated that Eva bought the property on the
-- 10th, and still owns it.

-- The time-slice as of January 18 tells a different story:
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-11 15:14:01+00:00'
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- On January 18 we thought that Eva had purchased the flat on January 10 and sold
-- it to Peter, who now owns it. A transaction time-slice can be visualized on
-- the time diagram as a vertical line situated at the specified date. This line
-- gives the valid-time history of the enterprise that was stored in the table
-- on that date.

-- Continuing, we take a transaction time-slice as of January 29:
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-11 15:14:01+00:00'
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- Give the history of owners of the flat at Skovvej 30 in Aalborg as best known
SELECT *
  FROM Prop_Owner
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- Only Peter ever had ownership of the property, since all records with a
-- valid-time duration of exactly one week were deleted. Peter's ownership was for
-- all of eight days, January 12 to January 20

-- We can also cut the time diagram horizontally. A valid time-slice of a
-- bitemporal table takes as input a valid-time instant and results in a
-- transaction-time state table capturing when information concerning that
-- specified valid time was recorded in the database


-- When was information about the owners of the flat at Skovvej 30 in Aalborg on
-- January 4, 1998, recorded in the Prop Owner table?
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR APPLICATION_TIME AS OF DATE '1998-01-04'
         AS x (customer_number, system_time_start, system_time_end);

-- Applying this time-slice results in one row, indicating that this information
-- - that the property was owned by Eva on January - was inserted into the table
-- on January 26 and subsequently deleted, as it was found to be incorrect, on
-- January 26.

-- The valid time-slice on January 13 is more interesting.
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR APPLICATION_TIME AS OF DATE '1998-01-13'
         AS x (customer_number, system_time_start, system_time_end);

-- NOTE: excess zero-width period appears - could be coalesced https://github.com/xtdb/core2/issues/403

-- A bitemporal time-slice query extracts a single point from a time diagram,
-- resulting in a snapshot table. A bitemporal time-slice takes as input two
-- instants, a valid-time and a transaction-time instant, and results in a
-- snapshot state of the information regarding the enterprise at that valid
-- time, as recorded in the database at that transaction time. The result is the
-- facts located at the intersection of the two lines, in this case, Eva.

-- Give the owner of the flat at Skovvej 30 in Aalborg on January 13 as stored
-- in the Prop Owner table on January 18.
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-11 15:14:01+00:00'
         FOR APPLICATION_TIME AS OF DATE '1998-01-13'
         AS x (customer_number, system_time_start, system_time_end);

-- [10.3.2] The Spectrum of Bitemporal Queries

-- Chapter 6 discussed the three major kinds of queries on valid-time state
-- tables: current ("valid now"), sequenced ("history of"), and nonsequenced
-- ("at some time"). Chapter 8 showed that there were three analogous kinds of
-- queries on transaction- time state tables: current ("as best known"),
-- sequenced ("when was it recorded"), and nonsequenced (e.g., "when was . . .
-- erroneously changed"). As a bitemporal table includes both valid-time and
-- transaction-time support, and as these two types of time are orthogonal, it
-- turns out that all nine combinations are possible on such tables.

-- To illustrate, we will take a nontemporal query and provide all the
-- variations of that query.

-- Before doing that, we add one more row to the Prop Owner table.
-- Peter Olsen bought another flat, at Bygaden 4 in Aalborg on January 15, 1998;
-- this was recorded on January 31, 1998.

INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start)
VALUES (2, 827, 3621, DATE '1998-01-15');

-- look again
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- Overlaying this information on the time diagram, we see that for five days
-- Peter owned two properties, at Bygaden and Skovvej; he sold the Skovvej
-- property on January 20, but retains the Bygaden property.

-- We start with a nontemporal query, a simple equijoin, pretending that the
-- Prop_Owner table is a snapshot table
-- What other properties are owned by the customer who owns property 7797?

SELECT P2.property_number
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS P1,
       Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS P2
 WHERE P1.property_number = 7797
   AND P2.property_number <> P1.property_number
   AND P1.customer_number = P2.customer_number;

-- 3 identical results

-- Case 1: Valid-time current and transaction-time current
-- What properties are owned by the customer who owns property 7797, as best
-- known?

SELECT P2.property_number
FROM Prop_Owner AS P1,
     Prop_Owner AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number;

-- Current in valid time is implemented by requiring that the period of validity
-- overlap "now"; current in transaction time is implicit. The result, a
-- snapshot table, is in this case the empty table because now, as best known,
-- no one owns property 7797. (Peter owned it for some nine days in January, but
-- doesn't own it now.)

-- Case 2: Valid-time sequenced and transaction-time current
-- What properties are or were owned by the customer who owned at the same time
-- property 7797, as best known?

SELECT P2.property_number,
       CASE
           WHEN P1.application_time_start < P2.application_time_start THEN P2.application_time_start
           ELSE P1.application_time_start
       END AS VT_Begin,
       CASE
           WHEN P1.application_time_end < P2.application_time_end THEN P1.application_time_end
           ELSE P2.application_time_end
       END AS VT_End
FROM Prop_Owner
FOR ALL APPLICATION_TIME AS P1,
        Prop_Owner
FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.application_time_start < P2.application_time_end
  AND P2.application_time_start < P1.application_time_end
  AND P1.system_time_end = END_OF_TIME
  AND P2.system_time_end = END_OF_TIME;

-- For those five days in January, Peter owned both properties

-- Case 3: Valid-time nonsequenced and transaction-time current
-- What properties were owned by the customer who owned at any time property
-- 7797, as best known?

SELECT P2.property_number
  FROM Prop_Owner FOR ALL APPLICATION_TIME AS P1, Prop_Owner FOR ALL APPLICATION_TIME AS P2
 WHERE P1.property_number = 7797
   AND P2.property_number <> P1.property_number
   AND P1.customer_number = P2.customer_number
   AND P1.system_time_end = END_OF_TIME
   AND P2.system_time_end = END_OF_TIME;

-- Peter owned both properties. While in this case there was a time when Peter
-- owned both properties simultaneously, the query does not require that. Even
-- if Peter had bought the second property on a valid time of January 31, that
-- property would still be returned by this query.

-- Case 4: Valid-time current and transaction-time sequenced
-- What properties did we think are owned by the customer who owns property
-- 7797?

SELECT P2.property_number,
       CASE
           WHEN P1.system_time_start < P2.system_time_start THEN P2.system_time_start
           ELSE P1.system_time_start
       END AS Recorded_Start,
       CASE
           WHEN P1.system_time_end < P2.system_time_end THEN P1.system_time_end
           ELSE P2.system_time_end
       END AS Recorded_Stop
FROM Prop_Owner FOR ALL SYSTEM_TIME AS P1,
     Prop_Owner FOR ALL SYSTEM_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.system_time_start < P2.system_time_end
  AND P2.system_time_start < P1.system_time_end;

-- The result, a snapshot table with two additional timestamp columns, is the
-- empty table because there was no time in which we thought that Peter
-- currently owns both properties.

-- Case 5: Valid-time sequenced and transaction-time sequenced
-- When did we think that some property, at some time, was owned by the customer
-- who owned at the same time property 7797?

SELECT P2.property_number,
       CASE
           WHEN P1.application_time_start < P2.application_time_start THEN P2.application_time_start
           ELSE P1.application_time_start
       END AS VT_Start,
       CASE
           WHEN P1.application_time_end < P2.application_time_end THEN P1.application_time_end
           ELSE P2.application_time_end
       END AS VT_End,
       CASE
           WHEN P1.system_time_start < P2.system_time_start THEN P2.system_time_start
           ELSE P1.system_time_start
       END AS Recorded_Start,
       CASE
           WHEN P1.system_time_end < P2.system_time_end THEN P1.system_time_end
           ELSE P2.system_time_end
       END AS Recorded_Stop
FROM Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P1,
     Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.application_time_start < P2.application_time_end
  AND P2.application_time_start < P1.application_time_end
  AND P1.system_time_start < P2.system_time_end
  AND P2.system_time_start < P1.system_time_end;

-- Here we have sequenced in both valid time and transaction time. This is the
-- most involved of all the queries. A query sequenced in both valid time and
-- transaction time, computing the intersection of two rectangle.
-- For those five days in January, Peter owned both properties. That information
-- was recorded on January 31 and is still thought to be true (a
-- transaction-stop time of "until changed").

-- Case 6: Valid-time nonsequenced and transaction-time sequenced
-- When did we think that some property, at some time, was owned by the customer
-- who owned at any time property 7797?

SELECT P2.property_number,
       CASE
           WHEN P1.system_time_start < P2.system_time_start THEN P2.system_time_start
           ELSE P1.system_time_start
       END AS Recorded_Start,
       CASE
           WHEN P1.system_time_end < P2.system_time_end THEN P1.system_time_end
           ELSE P2.system_time_end
       END AS Recorded_Stop
FROM Prop_Owner
FOR ALL SYSTEM_TIME
FOR ALL APPLICATION_TIME AS P1,
        Prop_Owner
FOR ALL SYSTEM_TIME
FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.system_time_start < P2.system_time_end
  AND P2.system_time_start < P1.system_time_end;

-- From January 31 on, we thought that Peter had owned those two properties,
-- perhaps not simultaneously.

-- Case 7: Valid-time current and transaction-time nonsequenced
-- When was it recorded that a property is owned by the customer who owns
-- property 7797?

SELECT P2.property_number,
       P2.system_time_start AS Recorded_Start
FROM Prop_Owner
FOR ALL SYSTEM_TIME AS P1,
        Prop_Owner
FOR ALL SYSTEM_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.system_time_start <= P2.system_time_start
  AND P2.system_time_start < P1.system_time_end;

-- The result, a snapshot table, is empty because we never thought that Peter
-- currently owns two properties.

-- Case 8: Valid-time sequenced and transaction-time nonsequenced
-- When was it recorded that a property is or was owned by the customer who
-- owned at the same time property 7797?

SELECT P2.property_number,
       CASE
           WHEN P1.application_time_start < P2.application_time_start THEN P2.application_time_start
           ELSE P1.application_time_start
       END AS VT_Begin,
       CASE
           WHEN P1.application_time_end < P2.application_time_end THEN P1.application_time_end
           ELSE P2.application_time_end
       END AS VT_End,
       P2.system_time_start AS Recorded_Start
FROM Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P1,
     Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.application_time_start < P2.application_time_end
  AND P2.application_time_start < P1.application_time_end
  AND P1.system_time_start <= P2.system_time_start
  AND P2.system_time_start < P1.system_time_end;

-- This query is similar to Case 2 (valid-time sequenced/transaction-time
-- current), with a different predicate for transaction time.
-- For those five days in January, Peter owned both properties; this information
-- was recorded on January 31

-- Case 9: Valid-time nonsequenced and transaction-time nonsequenced
-- When was it recorded that a property was owned by the customer who owned at
-- some time property 7797?

SELECT P2.property_number, P2.system_time_start AS Recorded_Start
  FROM Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P1,
       Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P2
 WHERE P1.property_number = 7797
   AND P2.property_number <> P1.property_number
   AND P1.customer_number = P2.customer_number
   AND P1.system_time_start <= P2.system_time_start
   AND P2.system_time_start < P1.system_time_end;

-- The two main points of this exercise are that all combinations do make sense,
-- and all can be composed by considering valid time and transaction time
-- separately.

-- Of these nine types of queries, a few are more prevalent. The most common is
-- the current/current queries, "now, as best known". These queries correspond
-- to queries on the nontemporal version of the table.

-- Perhaps the next most common kind of query is a sequenced/current query,
-- "history, as best known".
-- e.g. How has the estimated value of the property at Bygaden 4 varied over time?

-- Transaction time is supported in the Prop_Owner table to track the changes
-- and to correct errors. A common query searches for the transaction that
-- stored the current information in valid time. This is a current/nonsequenced
-- query.
-- e.g. When was the estimated value for the property at Bygaden 4 stored?

-- Sequenced/nonsequenced queries allow you to determine when invalid
-- information about the history was recorded.
-- e.g. Who has owned the property at Bygaden 4, and when was this information recorded?

-- Nonsequenced/nonsequenced queries can probe the interaction between valid
-- time and transaction time, identifying, for example, retroactive changes
-- e.g. List all retroactive changes made to the Prop Owner table

-- Bonus exercises for the reader:
-- Insert more data into Prop_Owner to cause entries to appear in results tables
-- where previously there were no results.
