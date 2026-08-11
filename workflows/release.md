# Workflow: Generic Release Readiness

Purpose: perform a final evidence-based go/no-go assessment. Do not modify repository files.

First determine or ask which release class applies: `FEATURE`, `BUGFIX`, or `HOTFIX`. If the task already specifies it, do not reclassify silently. Apply the matching release workflow requirements in addition to the common gates below.

## Common gates

1. Scope and version are explicit; no accidental files in status/diff.
2. Production code review has no unresolved BLOCKER/HIGH findings, or accepted exceptions are explicit.
3. Required build, unit, integration and smoke checks have evidence.
4. Database migrations/backfills are compatible, observable and reversible/roll-forwardable as appropriate.
5. API/event/schema/config compatibility is understood.
6. No leaked secrets, debug flags or unsafe defaults.
7. Runtime health/readiness, logging/metrics and operational runbook are adequate for the change.
8. Changelog/release notes and deployment steps match actual behavior.
9. Rollout, rollback trigger and rollback procedure are explicit.

Never convert missing evidence into PASS.

Return exactly one top-level decision: `RELEASE: PASS`, `RELEASE: PASS WITH WARNINGS`, or `RELEASE: FAIL`, then release class, evidence by gate, blockers/warnings, deployment and rollback checklist, and anything not verified.

## Workflow lock

ACTIVE WORKFLOW: /release

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
