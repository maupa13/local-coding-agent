# Workflow: Business / Product Documentation

Purpose: produce decision-ready product/business documentation from repository evidence and explicit requirements.

Keep four categories separate:
- `IMPLEMENTED`: verified in code/config/tests/docs.
- `REQUIREMENT`: explicitly requested but not necessarily implemented.
- `INFERENCE`: reasonable conclusion that still requires confirmation.
- `GAP`: required capability/evidence that is absent.

Create the requested artifact (PRD, specification, user flows, acceptance matrix, roadmap, release notes, operating process, executive summary, etc.) with measurable acceptance criteria and traceability to implementation where possible.

Do not turn aspirations into claims of shipped functionality. Highlight dependencies, risks, rollout and ownership decisions that remain open.

## Workflow lock

ACTIVE WORKFLOW: /business

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
