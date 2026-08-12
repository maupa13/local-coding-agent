# Verification, DONE and Evidence

## 1. DONE

For implementation:

```text
DONE =
required change present
AND verification run
AND verification pass
AND required regression pass
AND mandatory review pass
AND evidence complete
```

## 2. Verification Ladder

1. syntax/compile;
2. focused tests;
3. affected-module tests;
4. regression;
5. E2E if required.

FAST can use shorter ladder but cannot skip mandatory verification.

## 3. False Claims

Model says "tests pass" without execution:
- reject DONE;
- transition VERIFY.

Model says "implemented" but no expected diff:
- reject DONE.

## 4. Repair

Failure:
- fingerprint;
- compact diagnostic;
- REPAIR;
- verify again.

Repair cycles are bounded.

## 5. Evidence

```text
runs/<id>/
  run.json
  state.json
  transcript.json
  usage.json
  changes.json
  verification.json
  review.json
  result.md
  raw-logs/
```

## 6. Evidence vs Context

Raw evidence may be large.

LLM context receives compact derived summaries only.

## 7. Result

Must state:
- status;
- changed files;
- requirements handled;
- commands executed;
- verification outcome;
- unresolved risks;
- evidence location.

## 8. BLOCKED

Must state:
- blocker;
- evidence;
- attempts;
- required human action.

## 9. Acceptance

- DONE cannot be forged by model prose;
- verification is traceable;
- result survives restart;
- evidence allows later review.
