# Workflow: Test Engineering

Purpose: create or repair deterministic tests that validate behavior rather than implementation trivia.

- Discover existing test style, fixtures and build commands first.
- Identify behavior/acceptance criteria and failure modes to cover.
- Prefer JUnit 5 for Java. Use Testcontainers for database/broker/integration behavior when appropriate.
- Avoid sleeps for synchronization; use deterministic waiting/polling primitives or test-framework facilities.
- Keep tests isolated, repeatable and meaningful; do not weaken assertions merely to pass.
- Cover negative paths, boundary values, concurrency/idempotency where material.
- Run the targeted suite and relevant broader suite; diagnose flakes/failures.

Report tests added/changed, scenarios covered, commands/results, known gaps and flakiness risk.

## Recommended next gate

If production code or release scope changed, continue with `/review`; use the matching `/release-*` gate only after review evidence is available.

## Workflow lock

ACTIVE WORKFLOW: /test

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
