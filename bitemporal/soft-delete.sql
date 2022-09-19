-- Bitemporality offers a systematic approach to modelling 'soft deletes'

-- Build up from system time

-- Delete

-- Un-delete

INSERT INTO foo (id, application_time_start) VALUES (1, DATE '2023-01-01');

SELECT foo.id, foo.application_time_start, foo.application_time_end FROM foo;
