# Workflow: Workflow Catalog

Purpose: show the available Local Coding Agent workflows and help select one. This workflow is READ-ONLY.

When `/workflows` is invoked without a task, show the grouped catalog below. When a concrete task follows `/workflows`, recommend exactly one primary workflow and the next quality/release gate; do not modify files.

## Core

- `/analysis` — Read-only investigation: evidence, root cause, impact, next actions
- `/feature` — Implement a production-ready feature: acceptance → code → tests → verify
- `/bugfix` — Fix an existing defect: reproduce → root cause → regression → minimal fix
- `/hotfix` — Emergency production patch: minimal diff → focused checks → rollback-ready
- `/refactor` — Refactor internals while preserving behavior and external contracts

## Quality

- `/test` — Create/repair deterministic tests and verify relevant behavior
- `/review` — Read-only production review: correctness, concurrency, DB, security, tests

## Docs

- `/docs` — Create/update technical docs grounded in the actual repository
- `/business` — Create PRD/spec/user flows/acceptance/business documentation

## Specialist

- `/architecture` — Architecture analysis: options, trade-offs, boundaries, migration path
- `/migration` — Plan/implement safe schema, data, API or event migration
- `/performance` — Measure and improve latency/CPU/GC/DB/N+1/concurrency bottlenecks
- `/security` — Review/fix concrete security risks with regression verification

## Delivery

- `/deliver-feature` — Full feature delivery through verification and independent-review readiness
- `/deliver-bugfix` — Full bugfix delivery through regression and independent-review readiness
- `/deliver-hotfix` — Full hotfix delivery through focused verification and deploy/rollback prep

## Release

- `/release` — Generic read-only release gate: classify Feature/Bugfix/Hotfix and GO/NO-GO
- `/release-feature` — Feature Release gate: acceptance, review, E2E, rollout and rollback
- `/release-bugfix` — Bugfix Release gate: root cause, regression, blast radius and rollback
- `/release-hotfix` — Hotfix Release gate: accepted risk, rollback and post-deploy monitoring

## Standard chains

- Feature: `/feature` → `/test` → `/review` → `/release-feature`.
- Bugfix: `/bugfix` → `/test` → `/review` → `/release-bugfix`.
- Hotfix: `/hotfix` → focused `/test` → `/review` → `/release-hotfix`.
- Refactor: `/refactor` → `/test` → `/review`.
- Investigation only: `/analysis`.

Choose based on intent, not keywords alone. `/review` and all `/release-*` workflows are independent read-only gates; never treat an implementation workflow self-review as release approval.
## Reliable task format

For implementation, prefer a compact contract instead of a long conversational prompt:

```text
/deliver-feature
GOAL: ...
SOURCE: @docs/...
ACCEPTANCE: ...
CONSTRAINTS: ...
VERIFY: ...
```

Only `GOAL` is mandatory when the repository/documentation contains the rest.

If a previous workflow did work but failed to give a useful conclusion, run `/result`. It reconstructs a read-only final report from session context plus the real Git working tree.

## Workflow lock

ACTIVE WORKFLOW: /workflows

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
