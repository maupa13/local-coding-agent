# Installation, Upgrade and Release

## Installation

Primary user path should be simple.

First setup SHALL:
- detect dependencies;
- verify Ollama;
- verify candidate model;
- install runtime;
- safely integrate PowerShell/IDEA;
- run doctor.

Do not require insecure global ExecutionPolicy changes.

## PowerShell integration

Profile modifications must be:
- idempotent;
- bounded;
- removable;
- non-destructive to unrelated user profile content.

## Version marker

Installed runtime SHALL contain a candidate/version marker.

Tests must not qualify a different installed version.

## Lifecycle gates

Test:
- fresh install;
- repeated install;
- upgrade;
- repair;
- failed upgrade;
- rollback/recovery;
- uninstall;
- reinstall.

## Release qualification

Required chain:

```text
package validation
→ quick regression
→ full regression
→ install candidate
→ clean PowerShell startup
→ IDEA launcher
→ doctor deep
→ native runtime E2E
→ no-progress E2E
→ repair E2E
→ crash/recovery E2E
→ dirty-tree safety
→ concurrency
→ model compatibility
→ real-project smoke
→ uninstall/reinstall
```

## Skip policy

Required gate skipped:
```text
NOT QUALIFIED
```

All required pass:
```text
RELEASE VERDICT: GO
```

## Compatibility

Qualification should cover:
- Windows 11;
- PowerShell 5.1 where supported;
- PowerShell 7 where supported;
- paths with spaces;
- Cyrillic paths;
- IntelliJ supported editions;
- Git present/missing diagnostics;
- Ollama missing/unavailable diagnostics.
