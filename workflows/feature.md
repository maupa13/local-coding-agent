# Workflow: Implement Feature

Purpose: add requested functionality as a scoped, production-ready vertical slice without unrelated changes.

## Recommended task input

A short request is valid when it contains a goal and a discoverable requirements source. Prefer:

```text
/feature
GOAL: <what should exist>
SOURCE: @docs/... or repository documentation path
ACCEPTANCE: <known must-pass behavior; optional if fully specified by SOURCE>
CONSTRAINTS: <compatibility/scope constraints; optional if already in project rules>
VERIFY: <known build/test commands; otherwise discover from project>
```

If some sections are omitted, infer them from repository evidence and documentation rather than stopping. Ask only for a truly product-level decision that cannot be inferred safely.

## 1. Understand and discover

- Inspect the repository before proposing paths or symbols.
- Find existing analogous features and project conventions.
- Translate the task into explicit acceptance criteria and compatibility constraints.
- Identify affected API/UI, service/domain, persistence, messaging, configuration, observability and documentation layers only as applicable.
- Identify risks: transactions, concurrency, data migration, event contracts, security, performance and rollback.

## 2. Plan

Create a short implementation plan ordered by dependency. Prefer the smallest coherent vertical slice. Do not start a broad rewrite.

## 3. Implement

- Verify every target path exists before editing; create a file only when the design actually requires a new file.
- Preserve public API/schema/event compatibility unless the task explicitly changes it.
- Follow local project conventions.
- Add validation and explicit error handling.
- For Java/Spring: check transaction scope, blocking calls, JPA N+1, indexes, Kafka idempotency/retries, thread safety and resource lifecycle where relevant.
- Avoid `e.printStackTrace()`, swallowed exceptions, `Thread.sleep` for synchronization, disabled tests and placeholder production code.

## 4. Verify

- Add or update unit/integration tests for acceptance criteria.
- Prefer JUnit 5; use Testcontainers when real infrastructure behavior is material and the repository already supports it or adding it is justified.
- Run the narrowest relevant checks first, then broader build/test verification when feasible.
- Diagnose failures; do not hide or skip them to obtain green output.

## 5. Self-review

Inspect the final diff for scope creep, accidental files, compatibility, concurrency, database/query impact, security and observability.

## Result

Report acceptance criteria, files changed, tests/checks actually executed, results, compatibility/migration notes, remaining risks and anything not verified.

## Recommended next gates

After implementation, use `/test` for any remaining verification, then `/review`, then `/release-feature` when this change is a release candidate. Do not self-approve the release.

## Workflow lock

ACTIVE WORKFLOW: /feature

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
