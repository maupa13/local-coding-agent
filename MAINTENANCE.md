# Maintenance and release policy

## Development loop

After every Core/test change:

```powershell
.\VERIFY-PACKAGE.ps1
.\tests\RUN-ALL.ps1 -Profile Quick
```

Before publishing a candidate:

```powershell
.\tests\RUN-ALL.ps1 -Profile Full
```

Before stable release:

```powershell
.\tests\RUN-RELEASE-QUALIFICATION.ps1 -RealProject "C:\Projects\help-pass"
```

## Regression rule

Every production bug must become a permanent `REG-*` contract. Existing regression contracts are never removed merely to make a release green.

## Architecture rule

CLI, IDEA integration, future CI/service/API frontends must reuse the same Core contracts for routing, permissions, context, execution, quality and evidence. Frontends must not fork safety or quality logic.

## Version policy

The first public stable line is `1.0.0`. Earlier `2.0.0-alpha/beta/rc` identifiers are treated as internal prototype lineage and are retained in historical changelog only.

Promotion path:

`1.0.0-rc.N` → all gates GO → `1.0.0.RELEASE`.

No new feature is added between a green final RC and RELEASE; only packaging/version metadata may change.

## Gate responsibilities (rc.4+)

- **VERIFY-PACKAGE**: syntax, required assets, version/config/workflow/test-contract consistency. No real `cn`, Ollama, Git fixture, or installed-runtime execution.
- **Quick/Full**: regressions, fixture generation, lifecycle contracts.
- **Startup smoke**: installed runtime + IDEA launcher + local shell commands.
- **Live E2E**: real model performs compliance analysis, code/test bugfix, deterministic tests, and independent review on an isolated Git fixture.
- **Shell E2E**: the actual interactive shell accepts natural language, auto-routes, returns structured result, supports `/result` and local help.
- **QUALIFY-RELEASE.ps1**: one release gate over all of the above.
