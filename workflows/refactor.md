# Workflow: Refactor

Purpose: improve internal structure while preserving externally observable behavior unless the task explicitly requests a contract change.

1. Discover the real files, callers, tests and compatibility boundaries before editing.
2. State invariants that must remain unchanged: public API, schemas, event contracts, ordering, transaction semantics, performance-sensitive behavior.
3. Plan incremental transformations rather than a rewrite.
4. Make scoped changes following local conventions; remove duplication only when behavior is demonstrably equivalent.
5. Run existing tests; add focused characterization/regression tests where behavior is insufficiently protected.
6. Check SQL/query count/N+1, allocations/GC, concurrency and blocking behavior if the refactor touches hot paths.
7. Inspect final diff for accidental behavior changes and unrelated cleanup.

Report invariants, changes, verification, performance/compatibility impact, and remaining risk.

## Recommended next gates

Use `/test` to prove behavior preservation, then `/review` for an independent production-risk check.

## Workflow lock

ACTIVE WORKFLOW: /refactor

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
