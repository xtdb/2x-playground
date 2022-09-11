-- Data changes over time, and so does the schema
-- Traditional RDMS systems
-- Resolving queries across time in the face of changing schema

-- Dynamic joins (no foreign keys or referential integrity constraints)

-- Nested data, currently only supports round-tripping literals (nested querying is firmly on the roadmap, similar to https://partiql.org/)

INSERT INTO people (id, name, friends)
VALUES (5678,
        'Sarah',
        [{'user': 'Dan'},
         {'user': 'Kath'}]);

SELECT people.friends FROM people;


INSERT INTO people2 (id, name, friends)
VALUES (5678,
        'Sarah',
        {'user': 'Dan'}
        );

SELECT people2.id, people2.friends, {'user':'Dan'} FROM people2;

-- ARRAY
-- OBJECT

-- In future: triggers, assertions, invariants
