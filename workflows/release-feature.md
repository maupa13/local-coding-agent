# Workflow: Feature Release Gate

Release class: FEATURE — major/new functionality, scaling capability, or user-facing design/behavior change.
This workflow is READ-ONLY and is a final go/no-go gate.

## Required gates

- Feature acceptance criteria are complete and traceable to tests/evidence.
- `REVIEW` gate has no unresolved BLOCKER/HIGH issue.
- Unit/integration/E2E or equivalent tests cover the new user/system behavior.
- Backward compatibility of APIs, events, schemas and configuration is explicit.
- Migrations/backfills and mixed-version deployment behavior are safe where applicable.
- Performance/capacity impact is measured or justified for scaling/hot-path changes.
- Security/privacy impact and authorization changes are reviewed.
- User-facing UX/error states/accessibility/localization are checked when relevant.
- Observability supports rollout and failure diagnosis.
- Feature flag/canary/phased rollout is considered for high-risk changes.
- Documentation, versioning and release notes reflect the new capability.
- Rollback/disable path is executable and does not corrupt new data.

Decision must be one of:
`FEATURE RELEASE: PASS`
`FEATURE RELEASE: PASS WITH WARNINGS`
`FEATURE RELEASE: FAIL`

List blockers first, then evidence, warnings, rollout plan, rollback plan and unverified items.

## Workflow lock

ACTIVE WORKFLOW: /release-feature

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
