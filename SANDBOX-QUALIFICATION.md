# Sandbox qualification — 1.0.0-dev

**VERDICT: PASS**

PASS: 16 · FAIL: 0

| Check | Status | Detail |
|---|---|---|
| version sync | PASS | 1.0.0-dev |
| JSON/test/scenario schema | PASS | 44 tests, 22 scenarios |
| PowerShell single UTF-8 BOM | PASS | 61 files |
| core finalizer contracts | PASS | 172 functions, 0 duplicates |
| release fixture semantics | PASS | baseline PASS -> regression FAIL -> fixed PASS |
| compliance reference finalizer | PASS | 4 REQs; REQ-03 conservatively PARTIAL |
| terminal compliance transcript scope | PASS | rc.8 contaminated transcript rejected; canonical report accepted |
| compliance docs discovery/markdown forms | PASS | direct docs scan found REQ-01..REQ-05 across markdown variants |
| nonzero compliance finalizer | PASS | non-zero model exit still yields conservative local compliance finalization |
| diagnostic logging/static runtime selftest | PASS | persistent transcript + evidence dump + real PowerShell extractor self-test contracts present |
| log isolation/package contamination | PASS | runtime logs cannot self-contaminate package profile scan |
| rc.14 matrix-before-final accepted | PASS | rc.14 matrix-before-final accepted; Run-Step binding no longer uses CLIXML |
| variable-colon/stable dev workspace | PASS | no unsafe $variable: interpolation; stable dev folder + Git workflow present |
| StrictMode verifier hygiene | PASS | no unsafe double-quoted literal $variable verifier patterns |
| wrapper state machine | PASS | 7 state transitions |
| UTF-8 text hygiene | PASS | no known mojibake literal |

This suite runs in the build sandbox. Windows PowerShell 5.1, the installed Continue CLI, Ollama models, and IntelliJ IDEA still require target-machine qualification.
