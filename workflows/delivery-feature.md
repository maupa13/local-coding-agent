# Workflow: End-to-End Feature Delivery

Purpose: carry a scoped feature from repository analysis through implementation and verification to readiness for an independent review/release gate.

## Agentic intake contract

The user may provide only a goal plus a requirements source, for example:

```text
/deliver-feature
Implement the feature described by @docs/features/retry-task.md.
Definition of done: implementation, tests, verification, review-ready report.
```

From that input, autonomously:
1. resolve the requirements source and related repository documentation;
2. inspect existing architecture and analogous code;
3. derive a concrete acceptance checklist, marking inferred items as inference;
4. implement the smallest complete vertical slice;
5. run and repair targeted verification, then broader checks when feasible;
6. inspect the final diff and update required documentation;
7. finish review-ready with the mandatory final result.

Do not require the user to enumerate files that can be discovered from the repository. Do not stop merely to ask which class/file to edit.

Phases:
1. Intake: restate task, constraints and measurable acceptance criteria.
2. Discovery: inspect architecture, analogous code, contracts, migrations, UI/API/event impact and rollback constraints.
3. Plan: smallest coherent vertical slice and verification plan.
4. Implement: production code only within scope; preserve compatibility unless explicitly changed.
5. Test: add/update deterministic unit/integration/E2E coverage proportional to the feature.
6. Verify: execute targeted checks, then broader build/test checks when feasible; diagnose failures.
7. Self-review: inspect final diff for correctness, concurrency, security, DB/index/N+1, performance/GC, observability, compatibility and scope creep.
8. Documentation: update technical/user/release documentation required by the feature.
9. Release preparation: identify rollout/feature-flag/canary strategy, migration behavior, health checks and rollback.

Do not claim independent review approval. Finish with `DELIVERY: READY FOR INDEPENDENT REVIEW`, `DELIVERY: READY WITH WARNINGS`, or `DELIVERY: BLOCKED`, followed by acceptance evidence, files changed, tests, risks and the exact recommended next commands: `/review` then `/release-feature`.

## Workflow lock

ACTIVE WORKFLOW: /deliver-feature

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
