# Workflow: End-to-End Bugfix Delivery

Purpose: take a defect from evidence/root cause through a minimal verified correction to independent review/release readiness.

Phases:
1. Establish the failing behavior and blast radius.
2. Trace execution and state to a root cause.
3. Add/identify regression protection that demonstrates the defect.
4. Apply the minimum root-cause fix with no unrelated feature scope.
5. Run targeted and proportional broader regression/build checks.
6. Self-review compatibility, concurrency, security, performance and accidental scope.
7. Update release/technical notes only where behavior or operations changed.
8. Prepare deployment and rollback.

Finish with `DELIVERY: READY FOR INDEPENDENT REVIEW`, `DELIVERY: READY WITH WARNINGS`, or `DELIVERY: BLOCKED`, plus root cause, regression evidence, diff scope, test evidence, risks and next commands: `/review` then `/release-bugfix`.

## Workflow lock

ACTIVE WORKFLOW: /deliver-bugfix

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
