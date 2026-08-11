# Local Coding Agent 1.0.0-rc.2 — release candidate acceptance

The candidate is not a release until the complete qualification path passes on the target Windows machine.

## Mandatory sequence

```powershell
.\VERIFY-PACKAGE.ps1
.\tests\RUN-ALL.ps1 -Profile Quick
.\tests\RUN-ALL.ps1 -Profile Full
.\INSTALL.ps1 -InstallRecommendedModels
. .\ACTIVATE.ps1
agent-doctor -Deep
.\tests\RUN-RELEASE-QUALIFICATION.ps1 -RealProject "C:\Projects\help-pass"
```

Expected final line:

```text
RELEASE VERDICT: GO
```

## What the Release profile proves

- package/parser/contracts are valid under Windows PowerShell 5.1;
- historical regressions remain fixed;
- fixture/lifecycle/IDEA tests pass;
- installed runtime version equals candidate version;
- Ollama/Continue/runtime doctor is usable;
- supplied real project is a valid Git workspace;
- real LLM completes documentation compliance on an isolated fixture;
- real LLM fixes an intentional defect and adds regression coverage;
- deterministic `npm test` passes after the model edit;
- real LLM completes a read-only review of the resulting diff.

Any `NO-GO` or `NOT-QUALIFIED` blocks `1.0.0.RELEASE`.
