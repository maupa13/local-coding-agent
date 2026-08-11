# Workflow: Bugfix

Purpose: eliminate the underlying defect with the smallest safe change and regression evidence. Do not add unrelated scope.

## 1. Establish failure

- Reproduce the failure when practical, or establish it from code/tests/logs supplied by the user.
- Trace the real execution path and affected state/contracts.
- Separate symptom, triggering condition and root cause.

## 2. Root cause

Explain the root cause before editing. Check adjacent failure modes: retries, concurrency, null/edge input, transaction rollback, serialization, time zones, integer/precision behavior, data compatibility and resource cleanup as applicable.

## 3. Regression protection

Add or identify a test that fails because of the defect before the fix when practical. Preserve existing behavior outside the defect.

## 4. Fix

- Make the minimum safe correction at the root cause.
- Do not compensate with broad catch blocks, ignored exceptions, sleeps, disabled tests or duplicated workaround logic.
- Do not silently change public API/schema/event contracts.

## 5. Verify

Run targeted regression tests and then relevant broader tests/build. Inspect the final diff and check for performance/security/compatibility side effects.

## Result

Report: symptom, root cause, fix, regression test, verification evidence, files changed, remaining risks and anything not verified.

## Recommended next gates

After the fix, use `/test` for regression/broader verification, then `/review`, then `/release-bugfix` for the release candidate.

## Workflow lock

ACTIVE WORKFLOW: /bugfix

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.
