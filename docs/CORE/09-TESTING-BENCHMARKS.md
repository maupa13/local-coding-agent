# Testing and Benchmarks

## Core benchmark

Must exist before major platform expansion.

## Categories

At minimum:
- Java bugfix;
- Java feature;
- multi-file Spring change;
- regression test addition;
- refactor;
- DB migration;
- broken build recovery;
- documentation change;
- interrupted session;
- dirty-tree safety.

## Metrics

- verified completion rate;
- false-DONE;
- human intervention;
- files changed precision;
- repair count;
- repeated-action count;
- input/output tokens;
- duration;
- regression pass;
- user data loss;
- recovery success.

## Benchmark fixture rule

Every task SHALL define deterministic success criteria.

## Regression rule

Every product change includes:
- test for new behavior;
- regression for affected behavior;
- relevant previously fixed defect coverage.

## Java profile

Test:
- Java 21+;
- Maven;
- Gradle where supported;
- Spring Boot;
- JUnit 5;
- Testcontainers where applicable;
- spaces in path;
- Cyrillic path;
- dirty Git working tree.

## Comparative benchmark

Optional:
- same repository;
- same task;
- same acceptance;
- same model where possible.

Compare native LSDA worker with mature external engines only as evidence, not as a release dependency.

## Acceptance milestone

No public 1.0 before:
- false DONE = 0 in qualification suite;
- lost user changes = 0;
- unsafe destructive operations = 0;
- release evidence complete.
