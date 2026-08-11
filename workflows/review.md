# Workflow: Production Code Review

Purpose: perform an evidence-based review of the current change set or requested scope. This workflow is READ-ONLY: do not modify repository files.

## Scope discovery

1. Resolve the real repository root and current branch/HEAD.
2. Inspect `git status`, staged/unstaged diff, and relevant commit diff when available.
3. If there is no diff, use the task text to identify the concrete modules/files to review. Do not silently review the whole repository unless explicitly requested.
4. Read enough callers, tests, configuration, migrations and contracts to understand behavior around changed code.

## Review dimensions

Prioritize production risks over style:

- correctness and edge cases;
- concurrency, race conditions, locking and idempotency;
- transaction boundaries and partial-failure behavior;
- exception mapping, retries, timeouts and resource cleanup;
- security, authorization, input validation, secrets and unsafe defaults;
- data loss/corruption and migration compatibility;
- public API, persisted schema and event/message compatibility;
- Kafka delivery semantics, duplicate handling and ordering where relevant;
- SQL plans, indexes, N+1/query amplification and connection usage;
- CPU/memory allocation pressure, GC-sensitive hot paths and blocking I/O;
- observability: logs, metrics, tracing, auditability and actionable errors;
- deterministic test coverage including regression and integration behavior;
- deployment/rollback implications.

## Finding format

For every material finding provide:

- severity: `BLOCKER`, `HIGH`, `MEDIUM`, or `LOW`;
- exact file and symbol/line range when possible;
- concrete failure mode, not a vague concern;
- why it matters in production;
- a specific minimal fix;
- test/verification that proves the fix.

Do not invent findings to fill a quota. Avoid style-only comments unless they create maintainability or correctness risk.

## Gate

Finish with exactly one review gate:

- `REVIEW: PASS`
- `REVIEW: PASS WITH WARNINGS`
- `REVIEW: FAIL`

Then include:

- evidence inspected;
- ordered remediation plan (smallest safe order);
- release confidence: high / medium / low;
- anything not verified.

## Recommended next gate

If the review passes and the change is a release candidate, continue with exactly one of `/release-feature`, `/release-bugfix`, or `/release-hotfix` according to the release class.

## Workflow lock

ACTIVE WORKFLOW: /review

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
