# Testing and validation

```powershell
.\tests\RUN-ALL.ps1
.\tests\RUN-MODEL-EVAL.ps1
.\powershell\QUALIFY-RELEASE.ps1 -RealProject C:\path\to\git-project
```

The deterministic suite validates the wrapper, policies, paths and result contracts.
The model eval separately measures real local-model work on JavaScript, Python, Java
and PowerShell fixtures. Hidden oracles stay outside each fixture until the agent exits,
so model-written tests and reports cannot self-certify correctness.

A release requires both layers. Smoke tests such as creating `hello` or `test_calc.py`
prove only process/tool wiring and are never release evidence for coding quality.

