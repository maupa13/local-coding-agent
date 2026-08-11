# Workflow: Hotfix

Purpose: produce a minimal emergency correction for a critical production failure while controlling deployment risk. Urgency does not justify hidden risk or unrelated refactoring.

## 1. Incident scope

- State the production impact and the exact failure being mitigated.
- Identify the smallest affected execution path and blast radius.
- Confirm whether mitigation/config rollback exists before code changes.

## 2. Evidence and root cause

Use logs, failing behavior, tests or code evidence. Determine the most likely root cause with explicit confidence. If root cause cannot be fully proven under incident pressure, label the assumption and keep the patch reversible.

## 3. Minimal patch

- Change only what is required to restore safe behavior.
- No opportunistic cleanup, dependency upgrades or architectural refactors.
- Preserve external contracts unless changing them is the only safe emergency action and the impact is explicit.
- Prefer feature flag/config guard/rollback-friendly changes where appropriate.

## 4. Verification

- Add a focused regression test whenever technically possible.
- Run targeted tests and a smoke/build check appropriate to the affected component.
- Explicitly list any skipped verification and the risk accepted; never call skipped verification PASS.
- Inspect the diff for accidental scope.

## 5. Deployment safety

Prepare: deployment steps, health checks, rollback trigger, rollback procedure, metrics/logs to watch, and a post-deploy validation window.

## Result

Return `HOTFIX PATCH: READY`, `READY WITH ACCEPTED RISK`, or `NOT READY`, followed by root cause/confidence, exact change, tests, deployment/rollback checklist, monitoring signals and required follow-up work/postmortem.

## Recommended next gates

Use focused `/test`, then `/review`, then `/release-hotfix`. Urgency may narrow scope but must not silently skip the independent review/release gate.

## Workflow lock

ACTIVE WORKFLOW: /hotfix

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
