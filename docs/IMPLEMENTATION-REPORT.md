# Local Coding Agent — implementation and qualification report

Date: 2026-08-12  
Candidate: `1.0.0-dev.2`

## Executive verdict

The deterministic engineering runtime, package, Git guards, evidence, platform
gates, Quick and Full suites are working and qualified. Autonomous mutation with
the currently installed local 4B/9B models is useful but is not yet sufficiently
repeatable for unattended release work.

- Deterministic product/runtime: **GO**.
- Assisted development with review: **GO**.
- Unattended autonomous multi-file repair: **NO-GO** until the live benchmark is
  repeatable, not merely successful once.

## What was implemented

### Runtime and delivery contract

- Native Ollama tool loop for repository reads, bounded edits and allowlisted shell
  verification.
- Hardware-selected context, output, turn, tool, shell and repair budgets with
  validated user overrides.
- Git baseline/final-state evidence, unchanged HEAD enforcement, `git diff --check`,
  protected dependency manifests and forbidden-side-effect detection.
- Separate test/build and lint evidence; a model statement cannot substitute for a
  successful command.
- Persisted transcript, token usage, changed files, verification result, semantic
  result and final delivery report.
- Deterministic completion finalizers for complete compliance reports and verified
  mutation results.
- Repair routing that prevents repeated failing commands, bounds and deduplicates
  repair reads, and requires an edit before re-verification.
- JavaScript/Python post-edit syntax diagnostics and deterministic-test diagnostics,
  including side-effectful fake-clock detection.
- Spec-bound test prompting: tests must cover documented observable behavior without
  inventing public methods, return fields or exceptions.

### Stack gates

- Java 21/Temurin baseline, Maven and Gradle verification, Checkstyle.
- Kotlin and Detekt with gold and hidden contracts.
- Spring Boot 3 baseline, Boot 4 forward line, Boot 2/JDK 17/Gradle 7 legacy line.
- Separate `javax.persistence` and `jakarta.persistence` scenarios; Hibernate 6/7
  coverage contracts.
- Android SDK/API 36/37 and Android lint contracts.
- Python tests and quality checks.
- Rust tests, hidden contracts and Clippy.
- Frontend HTML/CSS/JavaScript tests and lint checks.
- Docker/Docker Compose, PowerShell, YAML, JSON, XML, BPMN and Jenkins validation.
- Feature, bugfix, refactor, test, release and system-analysis workflows plus Git
  safety scenarios.

## Qualification evidence

Latest deterministic results:

- Quick: 46/46 PASS, GO; reports are written below
  `%LOCALAPPDATA%\Temp\LocalCodingAgent\test-results\<run-id>\report.md`.
- Full: 53/53 PASS, GO; the report uses the same per-run evidence location.
- Real Shell E2E compliance workflow: PASS.
- Candidate installation and package preflight: PASS.
- Release qualification: deterministic, lifecycle, real-project and Shell gates
  pass; autonomous Live E2E remains the only failing class.

The autonomous benchmark is a clean Git fixture containing two source files, two
test files and eight behavioral requirements. It requires read-only analysis,
multi-file implementation, real `npm test`, Git evidence and an independent
read-only review.

Observed model behavior:

- `brnpistone/Qwen3.5-4B-AgentCoder-q6-k`: efficient tools, but unreliable reasoning
  around fake clocks and repair selection.
- `qwen3.5:9b-q4_K_M`: stronger analysis and reached a genuine 13/13 test PASS in one
  clean run, but subsequent clean runs over-generated tests and entered edit/read
  cycles. Increasing the budget from 64 to 120 turns did not make it repeatable.
- Other tested local coder/agent models either lacked reliable native tool calls or
  did not complete the mutation benchmark.

Therefore the remaining failure is model-policy quality and repeatability, not a
broken test runner, npm failure, Windows timeout or a falsely strict 20-turn cap.

## Hardware and configuration

Profiles live in `config/hardware-profiles.json` and may be selected automatically or
explicitly, with bounded overrides.

- Low VRAM (up to 7 GB): 4B/7B models, short analysis and small edits.
- Balanced (up to 12 GB): 9B work model, 16K context and long repair budget; suited
  to reviewed multi-file work.
- Large VRAM: larger context/models and broader repository snapshots.

Production recommendation on this machine:

- use `qwen3.5:9b-q4_K_M` for implementation/reasoning;
- use the 4B AgentCoder for quick navigation and simple edits;
- require Full/Release gates and human diff review before accepting mutation work;
- never treat model `PASS` as evidence without recorded lint/test/build ExitCode 0.

## Correct usage

1. Install the candidate with `powershell\INSTALL.ps1 -Force`.
2. Run `agent-doctor -Deep` after changing Java, Android, Rust, Node or Docker tools.
3. Start with `agent -Project "C:\path\to\project"`.
4. Use `/analysis` or `/review` for read-only work and `/deliver`, `/bugfix`,
   `/feature`, `/refactor` or `/test` for changes.
5. Inspect the reported changed files and evidence directory.
6. Run Quick during development, Full before handoff, and Release with a real project
   plus Live E2E before an unattended release claim.

## What works and what does not

Works:

- package/install/startup and IDEA integration;
- repository discovery, routing and read-only compliance analysis;
- guarded file/shell tools, Git safety and evidence persistence;
- deterministic JVM/Python/Rust/frontend/platform gold and hidden gates;
- lint/build/test orchestration and hardware configuration;
- assisted code changes where a developer reviews the diff and failed-test repair.

Not yet qualified:

- repeatable unattended multi-file repair with the installed small local models;
- a Codex-equivalent reasoning quality claim;
- release GO based on autonomous Live E2E across repeated clean runs.

## Recommended next improvements

1. Route implementation/review to a stronger 14B–32B coding model while retaining a
   smaller navigation model.
2. Add a separate test-author/reviewer pass that rejects duplicate, contradictory and
   undocumented tests before execution.
3. Add Java/Spring, Python, Rust and frontend autonomous live fixtures and require at
   least 4/5 clean-run success per fixture.
4. Add checkpoint/rollback and best-candidate selection instead of allowing one model
   to repeatedly rewrite a previously better test suite.
5. Record benchmark pass rate, turns, tokens, wall time and repair cycles per model;
   select models from measured task-class performance.
6. Only then promote unattended autonomous development from NO-GO to GO.

## Why the verdict is intentionally strict

A coding agent is valuable only when its evidence is more reliable than its prose.
One successful autonomous run proves capability; repeated clean runs prove a usable
product. The current implementation has the former, while deterministic and assisted
operation already have the latter.
