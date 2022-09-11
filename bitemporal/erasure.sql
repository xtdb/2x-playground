-- ERASE is a SQL DML command introduced by XTDB to erase ('hard delete') all bitemporal entries relating corresponding to a single record, or a collection of records

INSERT INTO monarchs (id, first_name) VALUES (123, 'Elizabeth');

INSERT INTO monarchs (id, first_name) VALUES (567, 'Charles');

SELECT *
  FROM monarchs
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               first_name,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);

ERASE FROM monarchs WHERE monarchs.first_name = 'Elizabeth';

SELECT *
  FROM monarchs
         FOR ALL SYSTEM_TIME
         FOR ALL APPLICATION_TIME
         AS x (id,
               first_name,
               application_time_start,
               application_time_end,
               system_time_start,
               system_time_end);
