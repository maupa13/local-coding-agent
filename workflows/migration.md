# Workflow: Migration

Purpose: design or implement a safe data/schema/API/runtime migration with backward compatibility and rollback.

- Inspect current schema/contracts/data access and deployment topology.
- State source state, target state, volume/locking constraints and compatibility window.
- Prefer expand -> migrate/backfill -> switch -> contract for zero/low-downtime changes.
- Consider indexes, lock duration, transaction size, retries, resumability, duplicate processing and observability.
- Provide forward verification and rollback/roll-forward strategy.
- Never drop/rename incompatible structures in the same deployment unless downtime and rollback consequences are explicit.

Report phases, scripts/code changed, verification, estimated operational risks and rollback plan.

## Workflow lock

ACTIVE WORKFLOW: /migration

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
