# Local Coding Agent 1.0.0-rc.2

## Release qualification — one command

For the release candidate, the primary developer-facing check is:

```powershell
.\QUALIFY-RELEASE.ps1 -RealProject "C:\Projects\help-pass"
```

It verifies package integrity, the Full regression suite, installs exactly this candidate, launches the CLI through the installed IDEA launcher, runs `agent-doctor`, executes a real-model coding E2E on an isolated fixture, and finally drives the real interactive shell with a natural-language documentation-compliance request. `RELEASE VERDICT: GO` is emitted only after every stage passes.

`VERIFY-PACKAGE.ps1` intentionally validates package/static correctness only; runtime behavior belongs to Quick/Full/Startup/E2E gates so a harness-specific integration probe cannot prevent a syntactically valid candidate from being installed and exercised.


Release candidate for the first public stable line. Local-first coding agent for Windows/IntelliJ IDEA built around Continue CLI + Ollama, with managed permissions, engineering workflows, evidence, deterministic quality gates, and regression/release qualification.

## Install candidate

```powershell
Set-Location "C:\AI\local-coding-agent-v1.0.0-rc.2"
Set-ExecutionPolicy -Scope Process Bypass -Force
.\VERIFY-PACKAGE.ps1
.\tests\RUN-ALL.ps1 -Profile Quick
.\tests\RUN-ALL.ps1 -Profile Full
.\INSTALL.ps1 -InstallRecommendedModels
. .\ACTIVATE.ps1
agent-doctor -Deep
```

Do not promote the build after any failed command.

## Normal use

From IDEA Run widget use `Local Coding Agent`, or:

```powershell
agent -Project "C:\Projects\help-pass"
```

Default session is `code + project` permissions: broad coding access inside the current project, while destructive Git/system operations remain blocked.

Useful controls: `/mode`, `/effort`, `/budget`, `/model`, `/permissions`, `/settings`, `/memory`, `/status`, `/result`, `/review`, `/release`.

Plain text is auto-routed.

## Release qualification

After the same candidate is installed:

```powershell
.\tests\RUN-RELEASE-QUALIFICATION.ps1 -RealProject "C:\Projects\help-pass"
```

This performs the Release profile with two runtime layers:

1. real-project smoke on the supplied Git repository (read-only/runtime checks);
2. isolated real-model E2E in `C:\AI\local-coding-agent-release-e2e`:
   documentation compliance → bugfix → deterministic `npm test` → independent review.

The supplied real project is **not mutated by release qualification**.

A Release profile without live E2E is `NOT-QUALIFIED`. Only `RELEASE VERDICT: GO` is eligible for promotion to `1.0.0.RELEASE`.

See `RELEASE-ACCEPTANCE.md` and `MAINTENANCE.md`.

## Safety boundary

`project`/`trusted` are managed tool policies, not a Windows kernel sandbox. External write paths, destructive Git, force-push, system shutdown/reboot, broad cleanup and similar dangerous operations remain restricted.

## Runtime

Installed runtime: `%USERPROFILE%\.continue\local-coding-agent`.
The installer writes a runtime `VERSION` marker so release tests cannot accidentally qualify an old installed Core against a newer package.
