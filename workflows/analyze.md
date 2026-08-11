# Workflow: Analysis

Purpose: inspect and explain the real repository/system without modifying files.

- Resolve repository scope and gather evidence with Search/List/Read/Diff and safe diagnostics.
- Distinguish confirmed facts, hypotheses and unknowns.
- Trace relevant control/data flow end to end.
- Identify correctness, architecture, performance, concurrency, database, messaging, security and operational implications as applicable.
- For problems, rank likely root causes by evidence and propose the smallest experiments/checks that distinguish them.

Do not invent implementation details. Finish with findings, evidence, impact, recommended next actions and unknowns.

When the task asks whether docs/specifications match the implementation, switch to compliance analysis: enumerate documented requirements, map each one to implementation and test evidence, identify contradictions/gaps, and produce a status matrix rather than a prose-only summary.

## Workflow lock

ACTIVE WORKFLOW: /analysis

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
