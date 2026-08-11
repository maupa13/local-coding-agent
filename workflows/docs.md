# Workflow: Technical Documentation

Purpose: create/update documentation grounded in the repository as it actually exists.

- Inspect implementation, commands, config and existing docs first.
- Prefer updating canonical existing documents over creating duplicates.
- Never document fictional endpoints, commands, environment variables or features as implemented.
- Clearly label planned/future behavior.
- Validate paths and runnable commands where feasible.
- Keep operational docs actionable: prerequisites, start/stop, health, troubleshooting, backup/restore and rollback where relevant.

Report documents changed, implementation evidence used and anything that could not be validated.

## Workflow lock

ACTIVE WORKFLOW: /docs

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
