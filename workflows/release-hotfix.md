# Workflow: Hotfix Release Gate

Release class: HOTFIX — emergency production patch for a critical live failure.
This workflow is READ-ONLY and is deliberately strict: urgency reduces scope, not evidence discipline.

## Required gates

- Incident severity/impact and affected production path are explicit.
- Patch is the smallest reversible change; no opportunistic refactoring or unrelated dependency upgrades.
- Root cause is proven or the remaining hypothesis/risk is explicitly accepted.
- Focused regression evidence exists whenever technically possible.
- `REVIEW` gate is complete; emergency review can be narrow but may not be silently skipped.
- Targeted test + build/smoke evidence exists; any skipped check is named with accepted risk.
- Deployment steps, immediate health checks and rollback trigger are prepared before release.
- Rollback/mitigation can be executed quickly and does not worsen data integrity.
- Metrics/logs/alerts to watch after deployment are explicit.
- Follow-up normal release, cleanup and postmortem items are recorded so emergency compromises do not become permanent.

Decision must be one of:
`HOTFIX RELEASE: PASS`
`HOTFIX RELEASE: PASS WITH ACCEPTED RISK`
`HOTFIX RELEASE: FAIL`

List blockers first, then accepted risks, exact patch scope, evidence, deploy/rollback checklist, post-deploy monitoring and follow-up work.

## Workflow lock

ACTIVE WORKFLOW: /release-hotfix

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
