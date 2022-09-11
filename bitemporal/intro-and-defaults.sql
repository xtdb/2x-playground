-- Welcome!

-- Use `psql` to follow along with confidence, although other Postgres-compatible tools and libraries should be possible to use also (e.g. Emacs SQLi)

-- A "Bitemporal Visualizer" GUI tool was created in support of this material, and is available on GitHub:
-- https://bitemporal-visualizer.github.io/

-- Useful commands:
\! clear -- clears the psql console, useful when discussing examples
\pset pager 0 -- avoids using the modal pager feature for wide result sets, so that results can be more easily copied from the console output

-- XTDB requires explicit IDs
-- There is no schema, all records exist in named tables
-- Columns are dynamic and all type handling is polymorphic
INSERT INTO foo (id, bar) VALUES ('a', 1);

-- TODO list of types for values and IDs

-- XTDB appears ~normal
-- Columns must therefore always be qualified with their table because there is no schema to infer from
SELECT foo.id, foo.bar FROM foo;

-- `SELECT *` will (currently) only return columns that appear elsewhere in the query
-- However it can be conveniently combined with derived columns to save some typing
SELECT * FROM foo AS x (id, bar);

-- Bitemporal invariants are built-in and automatic
-- XTDB maintains 4 time columns, immutably insertions, only closing the transaction_time_end
INSERT INTO foo (id, bar) VALUES ('a', 2);

-- XTDB maintains 4 time columns
SELECT *
  FROM foo AS x (id, bar, application_time_start, application_time_end, system_time_start, system_time_end)
 WHERE x.id = 'a';

-- multi-statement transactions
-- 1) not interactive
-- 2) only see state as-of the beginning of the transaction (intermediate states can't be observed, currently)
START TRANSACTION READ WRITE;
INSERT INTO foo (id, bar) VALUES ('a', 3);
INSERT INTO foo (id, bar) VALUES ('b', 4);
COMMIT;

-- can rollback
START TRANSACTION READ WRITE;
INSERT INTO example (id) VALUES (1234);
ROLLBACK;

SELECT foo.id, foo.bar FROM foo;

SELECT foo.id,
       foo.bar
  FROM foo
         FOR APPLICATION_TIME AS OF CURRENT_TIMESTAMP;

-- otherwise previous app_start will be used by default

-- therefore we will use XTDB's enhanced "AS_OF_NOW" temporal UX instead
SET SESSION CHARACTERISTICS AS APPLICATION_TIME_DEFAULTS AS_OF_NOW;

-- It can be reset as needed to compare & contrast
SET SESSION CHARACTERISTICS AS APPLICATION_TIME_DEFAULTS ISO_STANDARD;
-- But let's continue with XTDB's enhanced UX
SET SESSION CHARACTERISTICS AS APPLICATION_TIME_DEFAULTS AS_OF_NOW;


INSERT INTO posts (id, user_id, text, application_time_start)
VALUES (9012, 5678, 'Happy 2025!', DATE '2025-01-01');

SELECT posts.text FROM posts
                         FOR APPLICATION_TIME AS OF DATE '2025-01-02';

SELECT posts.text FROM posts;

-- FOR ALL works per table
-- FOR ALL SYSTEM_TIME must come before FOR ALL APPLICATION_TIME
