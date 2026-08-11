# Local Coding Agent 1.0.0 — release acceptance

`1.0.0.RELEASE` may be produced only from a release candidate that passes the complete qualification path on Windows PowerShell 5.1.

## Automated gate

```powershell
.\VERIFY-PACKAGE.ps1
.\tests\RUN-ALL.ps1 -Profile Quick
.\tests\RUN-ALL.ps1 -Profile Full
```

Install the same candidate, restart IDEA/runtime, then run:

```powershell
.\tests\RUN-RELEASE-QUALIFICATION.ps1 -RealProject "C:\Projects\help-pass"
```

The release qualification contains both:

- real-project/runtime smoke: installed runtime, model doctor, Git root;
- isolated **real LLM E2E** fixture: documentation compliance → bugfix → deterministic `npm test` → independent review.

The mutating E2E runs only in `C:\AI\local-coding-agent-release-e2e` by default and never modifies the supplied `-RealProject`.

## Release blockers

Any of these means **NO RELEASE**:

- PowerShell parser failure;
- regression/acceptance/lifecycle failure;
- installed runtime version mismatch;
- model/runtime doctor fatal failure;
- native stderr warning aborting a workflow;
- compliance run without a complete COMPLIANCE MATRIX;
- bugfix not reaching semantic PASS + quality PASS/PASS WITH WARNINGS;
- deterministic `npm test` failure after the real model edit;
- review run missing/blocked;
- release profile without `-LiveE2E` (`NOT-QUALIFIED`).

Only a final `RELEASE VERDICT: GO` from the Release profile with live E2E is eligible to be repackaged as `1.0.0.RELEASE`.

## Mandatory startup and behavior scenarios

A release candidate must additionally pass:

1. installed CLI startup through the same IDEA launcher used by a developer;
2. `/`, `/permissions`, `что ты можешь?`, `/project`, `/exit` without model invocation;
3. natural-language docs-compliance request through the interactive shell;
4. structured `COMPLIANCE MATRIX` and `/result`;
5. real bugfix which changes source and adds regression coverage;
6. deterministic project tests after the fix;
7. read-only analysis/review leave Git state unchanged;
8. harmless Git LF/CRLF stderr remains non-fatal;
9. test artifacts stay outside package and project roots;
10. installed runtime version equals the candidate version.

Preferred command: `./QUALIFY-RELEASE.ps1 -RealProject <repo>`.
