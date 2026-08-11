# Workflow: End-to-End Hotfix Delivery

Purpose: produce the smallest reversible emergency patch for a critical production failure and prepare it for immediate independent review/release gating.

Phases:
1. Incident scope: impact, affected path, current mitigation and rollback options.
2. Evidence/root cause: prove root cause where possible; otherwise state hypothesis/confidence explicitly.
3. Minimal patch: no unrelated cleanup, refactor or dependency upgrade.
4. Focused regression test and targeted build/smoke checks; list every skipped check and accepted risk.
5. Self-review for accidental scope, data integrity, security and rollback safety.
6. Prepare exact deployment steps, immediate health checks, rollback trigger/procedure and post-deploy metrics/logs.
7. Record follow-up normal-release cleanup/postmortem items.

Finish with `HOTFIX DELIVERY: READY FOR INDEPENDENT REVIEW`, `READY WITH ACCEPTED RISK`, or `BLOCKED`, then exact patch scope, evidence, accepted risks and next commands: `/review` then `/release-hotfix`.

## Workflow lock

ACTIVE WORKFLOW: /deliver-hotfix

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
