# Workflow: Performance

Purpose: diagnose and improve performance from evidence, not guesswork.

- Establish the measured symptom/baseline and workload.
- Trace CPU, latency, allocations/GC, contention, blocking I/O, DB queries/indexes/N+1, serialization, network and queue behavior as applicable.
- Rank bottleneck hypotheses and prefer measurement/profiling evidence.
- Make scoped optimizations that preserve correctness.
- Add/execute a representative benchmark or before/after measurement when feasible.

Report baseline, bottleneck evidence, change, before/after result, trade-offs and regression risk.

## Workflow lock

ACTIVE WORKFLOW: /performance

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
