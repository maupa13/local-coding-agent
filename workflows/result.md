# Workflow: Result / Recovery Summary

Purpose: recover a trustworthy final result when a previous workflow changed files, ran tools, or appeared to stop without a useful final synthesis. This workflow is read-only.

1. Inspect the current repository state with Git status/diff when available.
2. Use the current conversation/session context to identify the most recent requested workflow and intended acceptance criteria.
3. Inspect changed files; do not assume a tool call succeeded merely because it was attempted.
4. Use existing test/build output from the session as evidence. Run only safe read-only diagnostics; do not modify files.
5. If verification evidence is missing, mark it `NOT RUN` or `NOT VERIFIED` instead of inventing success.
6. Identify whether the implementation appears complete, partial, blocked, or failed.
7. Recommend exactly one next action: continue implementation, `/test`, `/review`, a release gate, or a concrete unblock action.

This command must always produce the mandatory final response structure from the execution reliability contract. `CHANGED FILES` must be derived from the real working tree/diff when Git is available.

## Workflow lock

ACTIVE WORKFLOW: /result

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
