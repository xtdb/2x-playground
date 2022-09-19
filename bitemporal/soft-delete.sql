SET application_time_defaults TO as_of_now;

-- WARNING: Correct use of this file assumes that you have already run the previous
-- command in an active XTDB connection

-- INTRODUCTION

-- Bitemporality offers a systematic approach to modelling 'soft deletes'

-- wiktionary.org: Soft deletion is an operation in which a flag is used to mark
-- data as unusable, without erasing the data itself from the database

-- PART 1: Userspace soft deletes

-- With a non-temporal RDBMS there are various schemes available to choose from,
-- e.g. you can using an auxiliary flag column and modify queries to check the
-- flag value These scehema invariably involves complexity trade-offs and can
-- interfere with normal use of uniqueness constraints, foreign key constraints,
-- cascade deletes, and schema updates

-- NOTE: In a regular RDBMS we would have to define a schema

-- A deleted_at column defaulting to NULL is a very simple soft delete model
INSERT INTO posts (id, message, deleted_at)
VALUES (123, 'Dear Values Customer...', NULL);

-- 'Normal' queries have to explicitly filter out these NULLS
SELECT posts.id,
       posts.message
FROM posts
WHERE posts.deleted_at IS NULL;

-- Soft deleting is a matter of setting the value to something, e.g. 'now'
UPDATE posts
SET deleted_at = CURRENT_TIMESTAMP
WHERE posts.id = 123;

-- The soft-deletion is now in effect
SELECT posts.id,
       posts.message
  FROM posts
 WHERE posts.deleted_at IS NULL;

-- We can retrieve the soft-deleted records if needed
SELECT posts.id,
       posts.message,
       posts.deleted_at
  FROM posts;

-- The record can be restored
UPDATE posts
   SET deleted_at = NULL
 WHERE posts.id = 123;

-- The restore is now in effect
SELECT posts.id,
       posts.message
  FROM posts
 WHERE posts.deleted_at IS NULL;

-- This very simple userspace soft-delete model doesn't track multiple data
-- versions or track the delete/restore activities in an auditable way


-- PART 2: Using bitemporality instead

-- With a temporal RDBMS like XTDB you can rely on regular DELETE to be soft and
-- retain access to historical versions

-- Insert draft message
INSERT INTO posts2 (id, message) VALUES (123, 'Dear Valued Customer...');

SELECT posts2.id, posts2.message FROM posts2;

-- Update draft message
UPDATE posts2
SET message = 'Dear Valued Customer?'
WHERE posts2.id = 123;

SELECT posts2.id, posts2.message FROM posts2;

-- Delete latest draft
DELETE FROM posts2 WHERE posts2.id = 123;

-- Confirm deletion as of 'now'
SELECT posts2.id, posts2.message FROM posts2;

-- See all history
SELECT posts2.id,
       posts2.message,
       posts2.application_time_start
  FROM posts2
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME;

-- This also returns 'deleted' row entries, which aren't needed here

-- Instead select only 'inserted' rows, i.e. Show versions
SELECT posts2.id,
       posts2.message,
       posts2.application_time_start
FROM posts2
FOR ALL SYSTEM_TIME
FOR ALL APPLICATION_TIME
WHERE posts2.APPLICATION_TIME OVERLAPS posts2.SYSTEM_TIME;

-- Select most recent version
SELECT posts2.id,
       posts2.message
  FROM posts2
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
 WHERE posts2.APPLICATION_TIME OVERLAPS posts2.SYSTEM_TIME
 ORDER BY posts2.application_time_start DESC
 LIMIT 1;

-- Un-delete/restore the most recent version
INSERT INTO posts2 (id, message)
SELECT posts2.id,
       posts2.message
FROM posts2
FOR ALL SYSTEM_TIME
FOR ALL APPLICATION_TIME
WHERE posts2.APPLICATION_TIME OVERLAPS posts2.SYSTEM_TIME
ORDER BY posts2.application_time_start DESC
LIMIT 1;

-- See the restored message
SELECT posts2.id, posts2.message FROM posts2;

-- Show versions
SELECT posts2.id,
       posts2.message,
       posts2.application_time_start
  FROM posts2
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
 WHERE posts2.APPLICATION_TIME OVERLAPS posts2.SYSTEM_TIME;

-- Un-delete/restore the first version
INSERT INTO posts2 (id, message)
SELECT posts2.id,
       posts2.message
  FROM posts2
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
 WHERE posts2.APPLICATION_TIME OVERLAPS posts2.SYSTEM_TIME
 ORDER BY posts2.application_time_start ASC
 LIMIT 1;

-- See the first message draft restored
SELECT posts2.id, posts2.message FROM posts2;

-- Is both application time _and_ system time required?
-- Not necessarily, but it is best to have both if:
--  - you want straightforward auditing
--  - you want an ability to migrate application times across databases
--  - you want to run queries that analyse across version changes

-- See also this advice for similarly using MariaDB's system versioned tables
-- functionality (i.e. not using application time also)
-- https://www.avaitla16.com/document-versioning-and-delete-from-recovery-in-mariadb
