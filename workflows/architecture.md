# Workflow: Architecture

Purpose: analyze current architecture and propose an implementable design with explicit trade-offs. Do not modify code unless separately requested.

- Map current components, dependencies, data flows, deployment/runtime and constraints from repository evidence.
- Capture non-functional requirements: throughput, latency, availability, consistency, security, operability, cost and team complexity.
- Present the recommended design plus at least one credible alternative when a real trade-off exists.
- Address API/events, persistence/indexing, concurrency, failure/retry semantics, observability, migration, backward compatibility and rollback.
- Prefer incremental evolution over unnecessary rewrites.

Return current-state summary, target design, decisions/trade-offs, migration stages, risks and verification/acceptance criteria.

## Workflow lock

ACTIVE WORKFLOW: /architecture

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
