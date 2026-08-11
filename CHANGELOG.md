# Local Coding Agent 1.0.0-dev

## Usability/runtime completion pass
- Managed/headless Continue execution now uses explicit headless stdout mode (`--silent`) and no longer forces the local run into CI mode.
- Runtime output is redirected to per-run files and polled while the task runs, so recognized file/tool activity is visible before completion.
- Normal mode emits a heartbeat every 10 seconds, warns after 60 seconds without new output, shows the child PID/model and `Ctrl+C` cancellation guidance, and enforces a 10-minute hard timeout that terminates the process tree.
- Russian requests explicitly instruct the model/recovery path to answer in Russian while preserving mandatory machine-readable `FINAL RESULT` / `WORKFLOW` headers.
- Normal UI no longer exposes the `Developer report` label; machine-readable evidence remains in the evidence directory.
- Git changes are now split into `changed by agent` versus `pre-existing changes` using per-run file hashes.
- Read-only analysis with no valid semantic model result is `FAIL`, not a provisional pseudo-`PARTIAL`.
- Added REG-038/REG-039 and SCN-023/SCN-024 for heartbeat/stall/timeout/language/change-accounting UX.


## Development workflow reset
- Versioned development directories are discontinued.
- Canonical source workspace is now `C:\AI\local-coding-agent`.
- Git checkpoints replace per-change ZIP/folder versioning during development.
- Added `DEV.ps1` with `status`, `checkpoint`, `test`, `install`, `qualify`, and `restore`.
- Release/RC version is not raised until the full real qualification reaches 7/7 PASS.
- Existing rc.16 runtime fixes remain included.


## Runtime diagnostics + harness correctness
- Accepted the real model layout where a canonical `COMPLIANCE MATRIX` table appears immediately before the terminal `FINAL RESULT`.
- Semantic status still comes exclusively from the last `FINAL RESULT`; transcript/rule text alone cannot satisfy compliance.
- Replaced the qualification CLIXML argument trampoline with direct PowerShell invocation so `-Profile Full`, `-Project <path>`, and other named arguments bind correctly.
- Child step exit codes are now authoritative; parameter-binding failures can no longer appear as false exit 0.
- Added staged diagnostics inside `Get-AgentComplianceRequirements` and removed the PS5.1-sensitive `TrimStart(char[])` path.
- Added REG-033/034/035 and SCN-018/019/020 for the exact rc.14 failures.
- No new end-user feature surface.


## Diagnostic isolation
- Moved qualification logs outside the package root to `%LOCALAPPDATA%\LocalCodingAgent\qualification\<version>-<timestamp>`.
- Added dedicated stdout/stderr log files for every qualification step.
- Hardened the package hardcoded-profile scan to inspect distributable source only and exclude transient runtime/log/evidence directories.
- Package profile failures now include matching file/line evidence.
- Added `REG-032` / `SCN-017` for log self-contamination.
- No new end-user feature surface.


## Diagnostic stabilization
- Added persistent full qualification transcript under `logs/QUALIFY-<version>-<timestamp>.log`.
- Added environment snapshot with PowerShell/OS/PATH/tool resolution for every qualification run.
- Added step path, arguments, start time, exit code and elapsed time logging.
- Added deep LIVE E2E failure diagnostics: fixture tree, requirements content, Git status, session metadata, model output, compliance recovery output, requirement-extraction diagnostics, native stderr/warnings, wrapper finalization and quality report.
- Failed LIVE E2E fixtures are preserved automatically for post-mortem inspection.
- Added runtime diagnostics inside `Get-AgentComplianceRequirements`: repository/docs roots, discovered files, lines read, per-document REQ matches and unique requirement IDs.
- Added a real Windows PowerShell module-scope self-test (`REG-030`) that invokes the actual internal compliance extractor against `NEW-RELEASE-E2E-REPO` before install/live model E2E.
- Added diagnostic logging regression (`REG-031`) plus SCN-015/SCN-016.
- No new end-user feature surface.


## Stabilization
- Fixed the rc.10 StrictMode regression verifier bug caused by a double-quoted regex containing a literal `$RepositoryRoot`.
- Added REG-028/SCN-013 to reject this entire class of verifier interpolation bugs before target-machine qualification.
- Re-separated qualification gates: `VERIFY-PACKAGE.ps1` validates package structure/syntax/version/test registry only; behavioral regression scripts run in `RUN-ALL -Profile Full`.
- No product feature changes.


## Stabilization
- Fixed deterministic compliance requirement extraction so recovery no longer depends on Git inventory/path normalization.
- Compliance finalization now scans `docs/` directly and merges repository-inventory results.
- Added support for common Markdown requirement forms (`REQ-01:`, bullets, bold IDs, headings, colon/dash separators).
- Added exact regression `REG-027` and scenario `SCN-012` for missing/incomplete Git inventory.
- No new end-user feature surface.


## Stabilization
- Fixed compliance validation to inspect only the last terminal `FINAL RESULT` block, not the entire Continue/tool transcript.
- Prevented rule/tool text mentioning `COMPLIANCE MATRIX`, PASS/FAIL, or evidence from creating false-positive compliance validation.
- Final-result persistence now saves only the terminal report block.
- Semantic status parsing now uses the last `FINAL RESULT` marker.
- Added exact regression for the real rc.8 transcript (`REG-026`, `SCN-011`).
- No new end-user feature surface.


## Stabilization
- Updated the beta reliability regression to the current wrapper-owned compliance finalization architecture.
- The regression now requires conservative PARTIAL finalization with no false PASS, plus authoritative FAIL when deterministic requirement extraction is impossible.
- Added permanent REG-024 preventing stale pre-finalizer contract checks from blocking future packages.
- No end-user feature changes.


## Stabilization
- Added wrapper-owned deterministic compliance finalization when the model fails to emit the required report.
- Added provisional generic finalization for incomplete model output; mutating workflows can be promoted to PASS only after deterministic checks and an independent review that does not fail.
- Forced UTF-8 for the Continue child process and redirected stdout/stderr to prevent Windows mojibake.
- Added REG-022/REG-023 and sandbox qualification scenarios.
- No new end-user feature surface.


## Stabilization
- Fixed `REG-020` test-matrix entry to use the canonical `id/area/description/test/tier` schema.
- Hardened `VERIFY-TEST-MATRIX.ps1` so malformed contracts fail with an explicit schema error instead of a PowerShell StrictMode property exception.
- Added permanent `REG-021` covering test-matrix schema integrity.
- No product functionality changes.

# Changelog

## 1.0.0-dev — Startup & Behavior Qualification

- Reworked Continue capture to use `System.Diagnostics.Process` with separate stdout/stderr streams; harmless Git LF/CRLF warnings no longer traverse the parent PowerShell error stream.
- `VERIFY-PACKAGE.ps1` is now a package/static gate and no longer executes runtime/native integration probes.
- Added installed CLI/IDEA-launcher startup smoke.
- Added real shell E2E: natural-language routing → docs compliance → `/result` → local capabilities → clean exit.
- Added `tests/SCENARIO-MATRIX.json`.
- Added one-command `QUALIFY-RELEASE.ps1` covering package → Full regression → install → startup → doctor → live coding E2E → shell E2E.
- Release remains blocked unless all scenario gates pass.

## 1.0.0-rc.2 — Public Release Candidate

- Rebased the public version line to 1.0.0; earlier 2.0.0 pre-release identifiers remain internal prototype history.
- Release profile now requires real live-model E2E and cannot qualify on static/runtime smoke alone.
- Added isolated release fixture: docs compliance → bugfix → deterministic Node tests → independent review.
- Added installed runtime VERSION marker and candidate/runtime mismatch gate.
- Added `RUN-RELEASE-QUALIFICATION.ps1` and release acceptance policy.
- Added REG-015 and ACC-005 release qualification contracts.

## 2.0.0-beta.2.1 — Regression Harness Hotfix

- Fixed Windows PowerShell 5.1 parser regression in the beta reliability code by simplifying dense native-command/pipeline expressions.
- Updated compact UI regression contracts to the current developer-progress UI (`Engineering execution`, `Deterministic verification`, clean console prompt).
- Updated multi-project UX regression contract for the new `[Console]::ReadLine()` prompt.
- `VERIFY-PACKAGE.ps1` now reports parser file, line, column and offending text for PowerShell syntax failures.
- No new end-user features.

## 2.0.0-beta.2 — Regression & Maintainability

- Added `tests/RUN-ALL.ps1` with Quick / Full / Release profiles.
- Added machine-readable `tests/TEST-MATRIX.json` and human maintenance policy.
- Historical user-visible failures are now permanent regression contracts.
- Release profile cannot report GO when real-project runtime evidence was not supplied.
- Test runs produce JSON + Markdown evidence under `test-results/`.
- Added installed-runtime + real-Git-project smoke gate for release qualification.
- Kept beta.2 intentionally feature-frozen: this release is about maintainability and regression control.

## 2.0.0-beta.2 — Engineering Quality

- Replaced opaque `Agent working...` with developer-progress: repository inventory, documentation scope, selected tool/build actions, model result, deterministic verification and quality status.
- Added documentation-compliance skill for `docs/spec ↔ implementation ↔ tests` analysis with a mandatory evidence matrix.
- Added lightweight repository inventory evidence before every managed workflow.
- Added verification freshness guard: if build/test commands mutate the working tree, checks rerun once against the resulting state; unstable mutation becomes a quality violation.
- Kept raw Continue output in evidence; `/verbose on` still exposes full output.
- No new providers/MCP/web execution in this release.

## 2.0.0-beta.2 — Coding Agent Core

- Added coding `/mode`: code, plan, debug, refactor, test, review, explain, docs.
- Added `/effort low|medium|high`.
- Added real `/budget` profiles and custom context/output settings; runtime Continue configs are patched per session.
- Added `project` permission mode as the new default for normal coding and opt-in `trusted` mode.
- Project mode permits broad repository editing/build/test and targeted dependency operations while keeping direct delete, destructive Git, system, Docker prune and shell-escape command classes blocked.
- Added project-specific `/memory` injected into managed workflow context.
- Added `/provider` settings foundation for later remote/OpenAI-compatible adapters; alpha.10 execution remains local/Ollama.
- Added mode-aware plain-text routing.
- Added session directive carrying mode, effort, budget and project memory.
- Added `VERIFY-CODING-CORE.ps1` regression coverage.
- Retained multi-project IDEA integration, Quality Engine, evidence/recovery and fail-closed installation.
- Explicitly documents that Continue/PowerShell permissions are not a kernel-level filesystem sandbox.

## 2.0.0-beta.2

- Multi-project IntelliJ IDEA integration: automatic scan of common project roots plus `agent-idea-all`.
- IDEA Run Configuration now embeds the resolved full Windows PowerShell interpreter path.
- Compact terminal header/prompt: `project · model-size · permission · QG✓` and `>`.
- Added `/settings` with clear global vs current-project settings.
- Global model/permission/Ollama settings separated from project-specific read directories.
- Installer treats the unpacked package as disposable distribution; runtime remains managed separately and receives its own `UNINSTALL.ps1`.
- Uninstall cleans registered Local Coding Agent IDEA Run Configurations when they are still owned by the agent.
- Review no longer auto-selects `qwen2.5-coder:7b` after it demonstrated missing native tool calls; the strong work model is the quality-first default reviewer in a fresh read-only session.
- Existing Quality Engine, model qualification, workflow skills, dependency firewall, and fail-closed installation remain unchanged.

## 2.0.0-alpha.9.4

- Added one-click IntelliJ IDEA project integration via `agent-idea` and optional installer `-IdeaProject`.
- Added a shared project Run Configuration named `Local Coding Agent` under `.idea/runConfigurations`.
- Run Configuration uses `$USER_HOME$` and `$PROJECT_DIR$`; no per-user or per-version absolute path is stored in the project.
- Added installed `IDEA-LAUNCH.ps1`, so existing project buttons automatically use the currently installed Local Coding Agent runtime after upgrades.
- Added `/idea install|status|remove` in Product CLI and standalone `IDEA-INTEGRATE.ps1`.
- Added release verification for IDEA integration contracts.

## 2.0.0-alpha.9.3

- Fixed the final false-negative release regression in `VERIFY-LAUNCHER-MODELS-SKILLS.ps1`: the test now checks the real `/model install` parser branch and `Install-AgentOllamaModel $Matches[1]` action instead of searching for an incorrectly escaped regex literal.
- No runtime behavior change from alpha.9.2; this is a release-verification hotfix.
- Full package verification remains fail-closed before model downloads or installation changes.

## 2.0.0-alpha.9.2

- Fixed `VERIFY-ENGINEERING-GUARDS.ps1`: `/deps on|off` now validates the real parser branch instead of a stale display string.
- Fixed `VERIFY-LAUNCHER-MODELS-SKILLS.ps1` under `Set-StrictMode`: `$arg` is now tested literally instead of interpolated.
- Installer now runs the full `VERIFY-PACKAGE.ps1` in a child Windows PowerShell process and aborts before any model/config changes on failure.
- Ollama model pulls now stream progress instead of appearing frozen during multi-gigabyte downloads.
- Installer warns when the extracted directory name does not match the package version.

## 2.0.0-alpha.9.1

- Fix stale PowerShell alias collisions (`agent -> cn`) by removing aliases as well as functions during activation/install.
- Force a global `agent -> Start-LocalCodingAgent` managed alias after activation and verify it; otherwise fail loudly.
- Add `/model setup`, `/model install <name>`, and `/model recommended` through Ollama HTTP API, transparent to Docker/native runtime.
- Default fast model changed to official `qwen3.5:4b`; independent review prefers installed `qwen2.5-coder:7b`.
- Add optional `INSTALL.ps1 -InstallRecommendedModels`.
- Add small workflow-specific skills: spec-driven feature, systematic debugging, verification-before-completion.
- Ollama host CLI is now optional; local HTTP API is authoritative.
- Stop overwriting global `~/.continue/config.yaml` by default; IDE/direct Continue integration is now explicit via `-InstallIdeConfig`.

## 2.0.0-alpha.9 — Product CLI + Model Roles

- Added compact product controls: `/model`, `/fast`, `/ask`, `/permissions`, `/status`, `/add-read-dir`.
- Added persistent work / fast / review model roles with Ollama discovery.
- Model selection now runs a native tool-calling smoke test before accepting a model into an agent role.
- Quality Engine review uses the dedicated review-model role instead of implicitly reusing the active work profile.
- Added `/deliver` alias for `/deliver-feature`; legacy workflows remain available through `/workflows`.
- Added deterministic plain-text intent routing; ambiguous requests default to read-only `/analysis`.
- Added `safe`, `ask`, and `readonly` permission modes. `ask` uses Continue session-level `--ask`; dangerous-command excludes and dependency firewall remain authoritative.
- Added persistent external read-only directories with `/add-read-dir` and `/sandbox-add-read-dir` alias.
- Added `/ask` quick read-only lane that preserves the main resumable task state.
- Added exported `agent-ask` for a second terminal while the main managed workflow is busy.
- Preserved compact captured output, deterministic build/test verification, diff-quality guards, dependency rollback, recovery and evidence.

## 2.0.0-alpha.8.2 — Compact Terminal + Quality Hardening

- Managed mode is quiet by default: Continue headless stdout is captured to evidence instead of repainted into Windows PowerShell.
- Added `/verbose on|off`; default is off.
- Added `/log`, `/log full`, and `/log open` for on-demand diagnostics.
- Terminal output is reduced to workflow stage, deterministic checks, quality result, elapsed time, changed-file count, and evidence path.
- Added diff quality signals for disabled/skipped tests, secret-looking changed files, oversized diffs, new TODO/FIXME/HACK markers, and missing regression-test changes on feature/bugfix flows when a test suite exists.
- Existing dependency firewall, requirements ingestion, deterministic build/test verification, recovery, and independent review remain enabled.


## 2.0.0-alpha.8.1 - Windows PowerShell hotfix

- Fixed Windows PowerShell 5.1 parsing failure in documentation-path ingestion.
- Requirement-source path detection now uses ASCII-only parser-sensitive regex and still accepts absolute Windows paths in Russian or English task text.
- Fixed `VERIFY-QUALITY-ENGINE.ps1` strict-mode interpolation of `$sourceBundle`.
- All `.ps1` / `.psm1` files are shipped as UTF-8 with BOM for Windows PowerShell 5.1.
- Added `VERIFY-PS51-COMPAT.ps1`.
- `INSTALL.ps1` now performs a mandatory parser/version preflight before touching existing Continue configuration or runtime.

## 2.0.0-alpha.8 — Lightweight Quality Engine

### Goal

Повысить фактическое качество реализации без разрастания интерфейса и без новых slash-workflows.

### Added

- lightweight post-implementation Quality Engine для code-oriented workflows;
- automatic stack detection и максимум 4 релевантных deterministic build/test checks;
- Rust/Cargo, Maven, Gradle, npm, pytest, Go, .NET и PowerShell syntax adapters;
- независимый короткий read-only post-review после успешных deterministic checks;
- `QUALITY SCORE: N/100` с разбивкой guardrails / verification / diff / finalization / review;
- wrapper downgrade/override модельного `PASS`, если объективные проверки его не подтверждают;
- `quality-report.txt`, `quality-check-*.txt`, `quality-review.txt` evidence;
- console summary `FINAL RESULT | QUALITY | SCORE`;
- external/local documentation ingestion before model execution;
- support for `@docs/...`, `SOURCE: ...`, `по пути F:\...`, explicit local files/directories;
- exact HTTP(S) documentation URL ingestion without general web search/crawling;
- `requirements-source.md` evidence bundle with bounded context budget;
- BLOCKED-before-implementation behavior when an explicitly supplied requirements source cannot be read;
- dedicated external-documentation acceptance fixture `NEW-DOC-SOURCE-REPO.ps1`.

### Permissions

- safe/common tools now run automatically instead of prompting repeatedly;
- `permissions.yaml` uses `Bash(*)` allow with explicit dangerous command exclusions;
- managed CLI also uses broad Bash allow plus deterministic deny patterns;
- read-only analysis/review/release processes exclude Bash entirely;
- VCS mutation (`commit`, `push`, `tag`, `checkout`, `switch`, `restore`, `rebase`, `merge`) is blocked in normal managed operation;
- destructive filesystem/system/container commands remain blocked;
- dependency mutation remains behind `/deps on`.
- managed `Fetch` is disabled for now; an exact user-supplied documentation URL is ingested only by the wrapper.
- unauthorized dependency manifest/lockfile mutations are restored from an exact pre-run snapshot and still fail the Quality Gate.

### Quality behavior

- deterministic failure or independent review `FAIL` overrides model `FINAL RESULT: PASS`;
- code workflow with no applicable deterministic verifier cannot receive a fully trusted PASS and is downgraded to PARTIAL;
- pre-existing dirty Git tree is surfaced as a warning;
- score is evidence-based, not a model confidence number.

### Kept intentionally out of scope

- general web search / autonomous current-information research;
- crawling arbitrary documentation sites;
- additional slash commands or role proliferation.
