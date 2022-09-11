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

/*
  Let's follow the history, over both valid time and transaction time, of a at
  in Aalborg, at Skovvej 30 for the month of January 1998.

  Starting with Current Modifications (Inserts, Updates, Deletes)

  INSERT INTO Prop_Owner (customer_number, property_number, VT_Begin,
  VT_End, TT_Start, TT_Stop)
  VALUES (145, 7797, CURRENT_DATE,
  DATE "9999-12-31", CURRENT_TIMESTAMP, DATE "9999-12-31")
*/

-- for XTDB an explicit ID is needed, let's not complicate everything with UUIDs for now...

SET SESSION CHARACTERISTICS AS APPLICATION_TIME_DEFAULTS AS_OF_NOW;

INSERT INTO Prop_Owner (id, customer_number, property_number)
VALUES (1, 145, 7797);

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
UPDATE Prop_Owner
   SET customer_number = 827
 WHERE Prop_Owner.property_number = 7797;

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

-- Sequenced Modifications - For bitemporal tables, the modication is sequenced only on valid time; the modication is always a current modification on transaction time, from now to until changed.

-- A sequenced insertion performed on January 23: Eva actually purchased the flat on January 3.
/*
INSERT INTO Prop_Owner (customer_number, property_number, VT_Begin,
                        VT_End, TT_Start, TT_Stop)
VALUES (145, 7797, DATE "1998-01-03",
        DATE "1998-01-10", CURRENT_TIMESTAMP, DATE "9999-12-31")*/

-- What was the earliest insert?
SELECT MIN(Prop_Owner.application_time_start)
 FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
 WHERE Prop_Owner.id = 1;

-- TODO https://github.com/xtdb/core2/issues/424 We can now use this value
INSERT INTO prop_owner (id, customer_number, property_number, application_time_start, application_time_end)
SELECT 1,
       145,
       7797, DATE '1998-01-03', tmp.app_start
FROM
  (SELECT MIN(Prop_Owner.system_time_start) AS app_start
      FROM Prop_Owner
             FOR ALL SYSTEM_TIME
             FOR ALL APPLICATION_TIME
    WHERE Prop_Owner.id = 1) AS tmp;

-- workaround
INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start, application_time_end)
VALUES (1, 145, 7797, TIMESTAMP '1998-01-03 00:00:00', TIMESTAMP '1999-01-03 00:00:00');

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
