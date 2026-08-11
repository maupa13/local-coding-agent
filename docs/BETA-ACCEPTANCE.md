# Local Coding Agent 2.0.0-beta.2.1 — acceptance bar

Beta.1 is feature-complete enough for real-project qualification. It is not a production release until these real Windows/IDEA scenarios pass.

1. `VERIFY-PACKAGE.ps1` passes completely on Windows PowerShell 5.1.
2. `agent-doctor -Deep` passes the primary work model and runtime checks with Ollama available.
3. `NEW-COMPLIANCE-REPO.ps1` + `проанализируй папку docs и проект на соответствие документации` returns a COMPLIANCE MATRIX that identifies the intentionally missing/broken behavior instead of all-PASS or reconnaissance-only BLOCKED.
4. The same compliance request on a real repository reads relevant docs/code/tests and returns a complete structured report.
5. Immediately typing `и?`, `и??`, `ну и?`, `итог?`, or `что в итоге?` prints the last full result without a new model run.
6. `session.json` records `before.isGit=true` and `after.isGit=true` for a real Git repository.
7. One real coding task in project mode changes the intended files, runs applicable build/tests after the last edit, and ends with a trustworthy Quality Gate result.
8. IDEA one-click launcher opens the managed shell for the current project without raw Continue TUI flicker.

Only after these pass repeatedly should the package move to release candidate.


## Automated regression gate (beta.2+)

Before publishing another beta, run:

```powershell
.\tests\RUN-ALL.ps1 -Profile Full
```

Before RC / RELEASE qualification, run:

```powershell
.\tests\RUN-ALL.ps1 -Profile Release -RealProject "C:\Projects\help-pass"
```

A `NOT-QUALIFIED` verdict is not a release pass. Interactive scenarios in this document still require attached evidence from actual model runs.
