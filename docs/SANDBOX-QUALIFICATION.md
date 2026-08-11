# Sandbox qualification — 1.0.0-dev

**VERDICT: PASS**

PASS: 26 · FAIL: 0

| Check | Status | Detail |
|---|---|---|
| version sync | PASS | 1.0.0-dev |
| JSON/test/scenario schema | PASS | 54 tests, 27 scenarios |
| PowerShell single UTF-8 BOM | PASS | 72 files |
| core finalizer contracts | PASS | 178 functions, 0 duplicates |
| release fixture semantics | PASS | baseline PASS -> regression FAIL -> fixed PASS |
| compliance reference finalizer | PASS | 4 REQs; REQ-03 conservatively PARTIAL |
| terminal compliance transcript scope | PASS | rc.8 contaminated transcript rejected; canonical report accepted |
| compliance docs discovery/markdown forms | PASS | direct docs scan found REQ-01..REQ-05 across markdown variants |
| nonzero compliance finalizer | PASS | non-zero model exit still yields conservative local compliance finalization |
| diagnostic logging/static runtime selftest | PASS | persistent transcript + evidence dump + real PowerShell extractor self-test contracts present |
| log isolation/package contamination | PASS | runtime logs cannot self-contaminate package profile scan |
| rc.14 matrix-before-final accepted | PASS | rc.14 matrix-before-final accepted; Run-Step binding no longer uses CLIXML |
| variable-colon/stable dev workspace | PASS | no unsafe $variable: interpolation; stable dev folder + Git workflow present |
| extractor generic-list free | PASS | compliance extractor/helper use plain PowerShell arrays only |
| runtime UX contract | PASS | heartbeat + stall timeout + Russian UX + per-run change accounting |
| DEV StrictMode exit code | PASS | DEV StrictMode-safe child-script exit handling present |
| Windows regression contract hygiene | PASS | Windows regressions no longer self-fail on stale architecture or StrictMode interpolation |
| project root selection | PASS | current directory wins; no cross-project fallback/status leakage; per-run changed count |
| document edit user journey | PASS | root main.md docs + edit->docs + zero-change FAIL |
| non-git inventory contract | PASS | non-git inventory + unborn HEAD + StrictMode-safe doc routing verifier |
| filesystem-first inventory | PASS | filesystem-first docs/source inventory independent of git state |
| PS5.1 path chars | PASS | single backslash char in PS5.1 inventory TrimStart |
| model tool gate | PASS | supported reasoning-off config + real cn edit gate + full smoke diagnostics |
| StrictMode verifier hygiene | PASS | no unsafe double-quoted literal $variable verifier patterns |
| wrapper state machine | PASS | 7 state transitions |
| UTF-8 text hygiene | PASS | no known mojibake literal |

This suite runs in the build sandbox. Windows PowerShell 5.1, the installed Continue CLI, Ollama models, and IntelliJ IDEA still require target-machine qualification.
