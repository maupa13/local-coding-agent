# Workflow: Bugfix Release Gate

Release class: BUGFIX — correction of an underlying defect, security issue, or performance flaw without intentional product scope expansion.
This workflow is READ-ONLY and is a final go/no-go gate.

## Required gates

- Original symptom and root cause are documented with evidence.
- Fix is scoped to the defect; unrelated feature scope is absent.
- Regression test or equivalent deterministic proof covers the defect.
- `REVIEW` gate has no unresolved BLOCKER/HIGH issue.
- Targeted tests pass; broader regression/build checks are proportional to blast radius.
- Compatibility of API/data/events/config is preserved or explicit.
- Security/performance impact is checked when the bug belongs to those classes.
- Deployment and rollback are straightforward and documented.
- Release notes state user/operator-visible effect without inventing scope.

Decision must be one of:
`BUGFIX RELEASE: PASS`
`BUGFIX RELEASE: PASS WITH WARNINGS`
`BUGFIX RELEASE: FAIL`

List blockers first, then root-cause/fix evidence, test evidence, blast radius, rollback and unverified items.

## Workflow lock

ACTIVE WORKFLOW: /release-bugfix

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
