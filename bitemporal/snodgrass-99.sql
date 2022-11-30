SET application_time_defaults TO as_of_now;

-- WARNING: Correct use of this file assumes that you have already run the previous
-- command in an active XTDB connection

-- INTRODUCTION

-- Derived from "Developing Time-Oriented Database Applications in SQL" by Richard T. Snodgrass
-- A digital copy of the book is available freely online from the author:
-- https://www2.cs.arizona.edu/~rts/tdbbook.pdf
-- This tutorial is based on the examples in Chapter 10 (p301 of the pdf)

-- NOTE:
--  transaction-time = system-time = "Recorded"
--  valid-time = application-time = "VT"
--  these source examples were written with example system-times during the year 1998
--  these source example assumed SQL-92 features and usage patterns

-- Various excerpts have been adapted and included below. However, the source
-- material (the book) is worth heavily referring to for the complete context,
-- and to compare the differences side-by-side between the SQL-92 examples and
-- XTDB's SQL:2011 implementation.

-- Use of https://bitemporal-visualizer.github.io/ is recommended.

-- BACKGROUND

-- Information is the key asset of many companies. Nykredit, a major Danish
-- mortgage bank, is a good example. In 1989, the Danish legislature changed the
-- Mortgage Credit Act to allow mortgage providers to market loans directly to
-- customers and through real estate agents

-- One of the challenges was achieving high data quality on the customers and
-- their loans, while expanding the traditional focus to also include customer
-- support. Managers needed access to up-to-date data to set benchmarks and
-- identify problems in various areas of the business. The sheer volume of the
-- data, nine million loans to eight million customers concerning seven million
-- properties, demands that eliminating errors in the data must be highly
-- efficient.

-- It was mandated that changes to critical tables be tracked. This implies that
-- the tables have system-time support. As these tables also model changes in
-- reality, they require application-time support. The result is termed a
-- bitemporal table, reflecting these two aspects of underlying temporal
-- support. With such tables, IT personnel can first determine when the
-- erroneous data was stored (a system time), roll back the table to that point,
-- and look at the application-time history. They can then determine what the
-- correct application-time history should be. At that point, they can tell the
-- customer service person what needs to be changed, or if the error was in the
-- processing of a user transaction, they may update the database manually.

-- [10.2] MODIFICATIONS

-- Let's follow the history, over both application time and system time, of a flat
-- in Aalborg, at Skovvej 30 for the month of January 1998.

-- Starting with Current Modifications (Inserts, Updates, Deletes)

-- For XTDB an explicit ID is needed, let's not complicate everything with UUIDs for now...

-- (MOD1) Eva Nielsen buys the flat at Skovvej 30 in Aalborg on January 10, 1998.
INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start)
VALUES (1, 145, 7797, DATE '1998-01-10');

-- Here we have but one region, associated with Eva Nielsen, that starts today
-- in system time and extends to until changed, and that begins also at
-- time 10 in application time and extends to forever.
SELECT *
  FROM Prop_Owner AS x (id,
                        customer_number,
                        property_number,
                        application_time_start,
                        application_time_end,
                        system_time_start,
                        system_time_end);

-- Paste the output of this query and others like it into https://bitemporal-visualizer.github.io/

-- (MOD2) Peter Olsen buys the flat; this legal system transfers ownership from Eva to him
INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start)
VALUES (1, 827, 7797, DATE '1998-01-15');

-- Observe the change in ownership as-of 'now'
SELECT *
  FROM Prop_Owner AS x (id,
                        customer_number,
                        property_number,
                        application_time_start,
                        application_time_end,
                        system_time_start,
                        system_time_end);

-- To see the _full_ history with our XT-specific application_time_defaults:
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

-- Note there a 3 entries. This is because the original validity region needed
-- "splitting" into two parts, so that the later part could be overridden by the
-- new value

-- (MOD3) We perform a current deletion when we find out that Peter has sold the
-- property to someone else, with the mortgage handled by another mortgage
-- company. From the bank's point of view, the property no longer exists as of
-- (an application time of) now.
DELETE
FROM Prop_Owner
     FOR PORTION OF APPLICATION_TIME FROM DATE '1998-01-20' TO END_OF_TIME
WHERE Prop_Owner.property_number = 7797;

-- See that the current view is deleted with the following returning 0 rows
SELECT *
  FROM Prop_Owner
         AS x (id,
               customer_number,
               property_number,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

-- If we now request the application-time history as best known, we will learn
-- that Eva owned the at from January 10 to January 15, and Peter owned the at
-- from January 15 to January 20. Note that all prior states are retained. We
-- can still time-travel back to January 18 and request the application-time
-- history, which will state that on that day we thought that Peter still owned
-- the at.
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

-- When visualized, the current deletion has "chopped off" the top-right corner,
-- so that the region is now L-shaped.

-- [10.2.2] Sequenced Modifications
-- For bitemporal tables, the modication is sequenced only on application time;
-- the modication is always a current modification on system time, from now to
-- until changed.

-- (MOD4) A sequenced insertion performed on January 23: Eva actually purchased the flat on January 3.
INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start, application_time_end)
VALUES (1, 145, 7797, DATE '1998-01-03', DATE '1998-01-10');

-- Look again
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

-- This insertion is termed a retroactive modification, as the period of
-- applicability is before the modification date Sequenced (and nonsequenced)
-- modifications can also be postactive, an example being a promotion that will
-- occur in the future (in application time).

-- (An application-end time of "forever" is generally not considered a postactive
-- modification; only the application-start time is considered.)

-- A sequenced modification might even be simultaneously retroactive,
-- postactive, and current, when its period of applicability starts in the past
-- and extends into the future (e.g., a fixed-term assignment that started in
-- the past and ends at a designated date in the future)

-- (MOD5) We learn now 26 that Eva bought the flat not on January 10, as initially
-- thought, nor on January 3, as later corrected, but on January 5. This
-- requires a sequenced version of the following deletion:
DELETE
FROM Prop_Owner
FOR PORTION OF APPLICATION_TIME
FROM DATE '1998-01-03' TO DATE '1998-01-05';

-- Look again
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

-- (MOD6) We next learn that Peter bought the flat on January 12, not January 15 as
-- previously thought. This requires a sequenced version of the following
-- update. This update requires a period of applicability of January 12 through
-- 15, setting the customer number to 145. Effectively, the ownership must be
-- transferred from Eva to Peter for those three days.
INSERT INTO Prop_Owner (id,
                        customer_number,
                        property_number,
                        application_time_start,
                        application_time_end)
VALUES (1, 145, 7797, DATE '1998-01-05', DATE '1998-01-12'),
       (1, 827, 7797, DATE '1998-01-12', DATE '1998-01-20');

-- Look again
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
-- application-time state tables; such statements treat the (application)
-- timestamps identically to the other columns.

-- As an example, consider the modification "Delete all records with a
-- application-time duration of exactly one week." This modifcation is clearly
-- (application-time) nonsequenced:
--  - it depends heavily on the representation, ooking for rows with a
--    particular kind of application timestamp,
--  - it does not apply on a per instant basis, and
--  - it mentions "records", that is, the recorded information, rather than
-- "reality".

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

-- NOTE: ideally we would use `7 DAY` here but that doesn't work currently,
-- blocked by https://github.com/xtdb/core2/issues/430

-- (MOD7) Now we can delete:
DELETE
FROM Prop_Owner
FOR ALL APPLICATION_TIME AS x
WHERE (x.application_time_end - x.application_time_start) = (DATE '1970-01-08' - DATE '1970-01-01');

-- Look again and observe that only the last row is now valid as of the current system time
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

-- A common query or view over the application-time state table is to capture
-- the state of the enterprise at some point in the past (or future). This query
-- is termed a application-time time-slice. For an auditable tracking log
-- changes, we might seek to reconstruct the state of the monitored table as of
-- a date in the past; this query is termed a system time-slice. As a bitemporal
-- table captures application and system time, both time-slice variants are
-- appropriate on such tables.

-- Time-slices are useful also in understanding the information content of a
-- bitemporal table. A system time-slice of a bitem- poral table takes as input
-- a system-time instant and results in a application-time state table that was
-- present in the database at that specified time.

-- A system time-slice query corresponds to a vertical slice in the time diagram.

-- A application time-slice query corresponds to a horizontal slice as input a
-- application-time instant and results in a system-time in the time diagram,
-- resulting in state table capturing when information concerning that specified
-- application time was recorded in the database. A application time-slice is a
-- system-time state table.

-- As mentioned earlier in this file, the system times in the examples are
-- historical (assumed to be executed in 1998) and must be adapted, so we will
-- use the 6 system_times returned by the following query, which are unique to
-- your active XTDB instance
SELECT DISTINCT x.system_time_start
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME AS x
 ORDER BY x.system_time_start ASC;

-- e.g.
--        system_time_start
--  -------------------------------
--  "2022-09-19T12:42:50.059747Z"
--  "2022-09-19T12:42:52.778407Z"
--  "2022-09-19T12:42:55.408391Z"
--  "2022-09-19T12:42:58.137604Z"
--  "2022-09-19T12:43:00.465137Z"
--  "2022-09-19T12:43:03.183066Z"

-- These correspond 1:1 with the following entries in the book:
--  DATE '1998-01-10'
--  DATE '1998-01-15'
--  DATE '1998-01-23'
--  DATE '1998-01-26'
--  DATE '1998-01-28'
--  DATE '1998-01-30'

-- You may want to paste these values side-by-side in a spreadsheet or other
-- table format for ease of reference

-- You will need to interpolate your own system timestamps where the examples
-- demand values other than those listed (e.g. 14 Jan is ~any time between rows
-- #1 and #2)

-- NOTE: double-quotes are not supported for values in ISO SQL, therefore Be
-- sure to replace the JSON double-quotes with single quotes when copying the
-- literals for use with TIMESTAMP

-- Give the history of owners of the flat at Skovvej 30 in Aalborg as of before our session began:
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-19T12:42:50.059747Z'
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- Applying this time-slice results in an empty table, as no history was yet
-- known about that property.

-- Taking a system time-slice as of January 14 results in a history with one entry:
-- i.e. use a TIMESTAMP between the 1st and 2nd entries (do this similarly again hereafter)
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-19T12:42:51Z'
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
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-19T12:42:53Z'
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- On January 18 we thought that Eva had purchased the flat on January 10 and sold
-- it to Peter, who now owns it. A system time-slice can be visualized on
-- the time diagram as a vertical line situated at the specified date. This line
-- gives the application-time history of the enterprise that was stored in the table
-- on that date.

-- Continuing, we take a system time-slice as of January 29:
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-19T12:43:01Z'
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- Give the history of owners of the flat at Skovvej 30 in Aalborg as best known
SELECT *
  FROM Prop_Owner
         FOR ALL APPLICATION_TIME
         AS x (customer_number, application_time_start, application_time_end);

-- Only Peter ever had ownership of the property, since all records with a
-- application-time duration of exactly one week were deleted. Peter's ownership was for
-- all of eight days, January 12 to January 20

-- We can also cut the time diagram horizontally. A application time-slice of a
-- bitemporal table takes as input a application-time instant and results in a
-- system-time state table capturing when information concerning that
-- specified application time was recorded in the database


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

-- The application time-slice on January 13 is more interesting.
SELECT *
  FROM Prop_Owner
         FOR ALL SYSTEM_TIME
         FOR APPLICATION_TIME AS OF DATE '1998-01-13'
         AS x (customer_number, system_time_start, system_time_end);

-- NOTE: excess zero-width period appears - could be coalesced
-- (TODO https://github.com/xtdb/core2/issues/403)

-- A bitemporal time-slice query extracts a single point from a time diagram,
-- resulting in a snapshot table. A bitemporal time-slice takes as input two
-- instants, a application-time and a system-time instant, and results in a
-- snapshot state of the information regarding the enterprise at that application
-- time, as recorded in the database at that system time. The result is the
-- facts located at the intersection of the two lines, in this case, Eva.

-- Give the owner of the flat at Skovvej 30 in Aalborg on January 13 as stored
-- in the Prop Owner table on January 18.
SELECT *
  FROM Prop_Owner
         FOR SYSTEM_TIME AS OF TIMESTAMP '2022-09-19T12:42:53Z'
         FOR APPLICATION_TIME AS OF DATE '1998-01-13'
         AS x (customer_number, system_time_start, system_time_end);

-- [10.3.2] The Spectrum of Bitemporal Queries

-- Chapter 6 discussed the three major kinds of queries on application-time state
-- tables: current ("application now"), sequenced ("history of"), and nonsequenced
-- ("at some time"). Chapter 8 showed that there were three analogous kinds of
-- queries on system-time state tables: current ("as best known"),
-- sequenced ("when was it recorded"), and nonsequenced (e.g., "when was ...
-- erroneously changed"). As a bitemporal table includes both application-time and
-- system-time support, and as these two types of time are orthogonal, it
-- turns out that all nine combinations are possible on such tables.

-- To illustrate, we will take a nontemporal query and provide all the
-- variations of that query.

-- (MOD8) Before doing that, we add one more row to the Prop Owner table.
-- Peter Olsen bought another flat, at Bygaden 4 in Aalborg on January 15, 1998;
-- this was recorded on January 31, 1998.
INSERT INTO Prop_Owner (id, customer_number, property_number, application_time_start)
VALUES (2, 827, 3621, DATE '1998-01-15');

-- Look again
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

-- Case 1: Application-time current and system-time current
-- What properties are owned by the customer who owns property 7797, as best
-- known?

SELECT P2.property_number
FROM Prop_Owner AS P1,
     Prop_Owner AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number;

-- Current in application time is implemented by requiring that the period of validity
-- overlap "now"; current in system time is implicit. The result, a
-- snapshot table, is in this case the empty table because now, as best known,
-- no one owns property 7797. (Peter owned it for some nine days in January, but
-- doesn't own it now.)

-- Case 2: Application-time sequenced and system-time current
-- What properties are or were owned by the customer who owned at the same time
-- property 7797, as best known?

SELECT P2.property_number,
       GREATEST(P1.application_time_start, P2.application_time_start) AS VT_Begin,
       LEAST(P1.application_time_end, P2.application_time_end) AS VT_End
FROM Prop_Owner
FOR ALL APPLICATION_TIME AS P1,
        Prop_Owner
FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.APPLICATION_TIME OVERLAPS P2.APPLICATION_TIME;

-- For those five days in January, Peter owned both properties

-- Case 3: Application-time nonsequenced and system-time current
-- What properties were owned by the customer who owned at any time property
-- 7797, as best known?

SELECT P2.property_number
  FROM Prop_Owner FOR ALL APPLICATION_TIME AS P1, Prop_Owner FOR ALL APPLICATION_TIME AS P2
 WHERE P1.property_number = 7797
   AND P2.property_number <> P1.property_number
   AND P1.customer_number = P2.customer_number;

-- Peter owned both properties. While in this case there was a time when Peter
-- owned both properties simultaneously, the query does not require that. Even
-- if Peter had bought the second property on a application time of January 31, that
-- property would still be returned by this query.

-- Case 4: Application-time current and system-time sequenced
-- What properties did we think are owned by the customer who owns property
-- 7797?

SELECT P2.property_number,
       GREATEST(P1.system_time_start, P2.system_time_start) AS Recorded_Start,
       LEAST(P1.system_time_end, P2.system_time_end) AS Recorded_Stop
FROM Prop_Owner FOR ALL SYSTEM_TIME AS P1,
     Prop_Owner FOR ALL SYSTEM_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.SYSTEM_TIME OVERLAPS P2.SYSTEM_TIME;

-- The result, a snapshot table with two additional timestamp columns, is the
-- empty table because there was no time in which we thought that Peter
-- currently owns both properties.

-- Case 5: Application-time sequenced and system-time sequenced
-- When did we think that some property, at some time, was owned by the customer
-- who owned at the same time property 7797?

SELECT P2.property_number,
       GREATEST(P1.application_time_start, P2.application_time_start) AS VT_Begin,
       LEAST(P1.application_time_end, P2.application_time_end) AS VT_End,
       GREATEST(P1.system_time_start, P2.system_time_start) AS Recorded_Start,
       LEAST(P1.system_time_end, P2.system_time_end) AS Recorded_Stop
FROM Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P1,
     Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.APPLICATION_TIME OVERLAPS P2.APPLICATION_TIME
  AND P1.SYSTEM_TIME OVERLAPS P2.SYSTEM_TIME;

-- Here we have sequenced in both application time and system time. This is the
-- most involved of all the queries. A query sequenced in both application time and
-- system time, computing the intersection of two rectangle.
-- For those five days in January, Peter owned both properties. That information
-- was recorded on January 31 and is still thought to be true (a
-- system-stop time of "until changed").

-- Case 6: Application-time nonsequenced and system-time sequenced
-- When did we think that some property, at some time, was owned by the customer
-- who owned at any time property 7797?

SELECT P2.property_number,
       GREATEST(P1.system_time_start, P2.system_time_start) AS Recorded_Start,
       LEAST(P1.system_time_end, P2.system_time_end) AS Recorded_Stop
FROM Prop_Owner
FOR ALL SYSTEM_TIME
FOR ALL APPLICATION_TIME AS P1,
        Prop_Owner
FOR ALL SYSTEM_TIME
FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.SYSTEM_TIME OVERLAPS P2.SYSTEM_TIME;

-- From January 31 on, we thought that Peter had owned those two properties,
-- perhaps not simultaneously.

-- Case 7: Application-time current and system-time nonsequenced
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
  AND P1.SYSTEM_TIME CONTAINS PERIOD(P2.system_time_start, P2.system_time_start);

-- The result, a snapshot table, is empty because we never thought that Peter
-- currently owns two properties.

-- Case 8: Application-time sequenced and system-time nonsequenced
-- When was it recorded that a property is or was owned by the customer who
-- owned at the same time property 7797?

SELECT P2.property_number,
       GREATEST(P1.application_time_start, P2.application_time_start) AS VT_Begin,
       LEAST(P1.application_time_end, P2.application_time_end) AS VT_End,
       P2.system_time_start AS Recorded_Start
FROM Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P1,
     Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P2
WHERE P1.property_number = 7797
  AND P2.property_number <> P1.property_number
  AND P1.customer_number = P2.customer_number
  AND P1.APPLICATION_TIME OVERLAPS P2.APPLICATION_TIME
  AND P1.SYSTEM_TIME CONTAINS PERIOD(P2.system_time_start, P2.system_time_start);

-- This query is similar to Case 2 (application-time sequenced/system-time
-- current), with a different predicate for system time.
-- For those five days in January, Peter owned both properties; this information
-- was recorded on January 31

-- Case 9: Application-time nonsequenced and system-time nonsequenced
-- When was it recorded that a property was owned by the customer who owned at
-- some time property 7797?

SELECT P2.property_number, P2.system_time_start AS Recorded_Start
  FROM Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P1,
       Prop_Owner FOR ALL SYSTEM_TIME FOR ALL APPLICATION_TIME AS P2
 WHERE P1.property_number = 7797
   AND P2.property_number <> P1.property_number
   AND P1.customer_number = P2.customer_number
   AND P1.SYSTEM_TIME CONTAINS PERIOD(P2.system_time_start, P2.system_time_start);

-- The two main points of this exercise are that all combinations do make sense,
-- and all can be composed by considering application time and system time
-- separately.

-- Of these nine types of queries, a few are more prevalent. The most common is
-- the current/current queries, "now, as best known". These queries correspond
-- to queries on the nontemporal version of the table.

-- Perhaps the next most common kind of query is a sequenced/current query,
-- "history, as best known".
-- e.g. How has the estimated value of the property at Bygaden 4 varied over time?

-- System time is supported in the Prop_Owner table to track the changes
-- and to correct errors. A common query searches for the underlying transaction that
-- stored the current information in application time. This is a current/nonsequenced
-- query.
-- e.g. When was the estimated value for the property at Bygaden 4 stored, and
-- what other data was stored at the same time?

-- Sequenced/nonsequenced queries allow you to determine when invalid
-- information about the history was recorded.
-- e.g. Who has owned the property at Bygaden 4, and when was this information recorded?

-- Nonsequenced/nonsequenced queries can probe the interaction between application
-- time and system time, identifying, for example, retroactive changes
-- e.g. List all retroactive changes made to the Prop Owner table




-- Bonus exercises for the reader:

-- 1) Insert more data into Prop_Owner to cause entries to appear in results
-- tables where previously there were no results.

-- 2) Try out all of the period predicates to see how they behave

-- 3) Invent your own example for one of the 9 types of bitemporal queries (pick
-- one that interests you!)
