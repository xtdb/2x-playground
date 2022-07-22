
SELECT users.name from users;

SELECT schemaless_table.name from schemaless_table;

SELECT foo.name, bar.name FROM foo, bar
WHERE foo.APP_TIME SUCCEEDS bar.APP_TIME;

-- doesn't work yet:
-- SELECT foo.name, bar.name FROM foo, bar
-- WHERE foo.APP_TIME IMMEDIATELY SUCCEEDS bar.APP_TIME;

SELECT foo.name FROM foo
WHERE foo.APP_TIME OVERLAPS PERIOD (TIMESTAMP '3500-01-01 00:00:00', TIMESTAMP '4001-01-01 00:00:00');

-- returns no rows, since we didn't insert any data before 2000-01-01:
SELECT foo.last_updated FROM foo
FOR SYSTEM_TIME AS OF TIMESTAMP '2000-01-01 00:00:00';
