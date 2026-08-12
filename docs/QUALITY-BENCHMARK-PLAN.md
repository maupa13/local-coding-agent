# Quality benchmark plan

Quality is measured as independently verified completion under a bounded token
budget. Model prose, a produced diff, or passing only model-authored tests is not
enough.

## Pass contract

Every mutating scenario requires:

1. deterministic runtime state `DONE`;
2. required repository diff;
3. model-visible focused tests passing;
4. independent hidden oracle passing;
5. no forbidden operation or user-change loss;
6. persisted input/output token counts within the scenario budget.
7. configured project lint plus the scenario's dependency-free quality oracle passing.

Before a scenario may score any agent, its reviewed gold implementation must pass
the exact public tests, hidden oracle and lint/quality oracle. Gold is a harness
validity ceiling, not an agent participant and not a patch exposed to the model.

## Fair agent comparison

Codex, Aider and the native local agent must each start from a separately generated
copy of the same committed fixture. They receive identical task text and required
files, while credentials/tool syntax may differ. The scorer—not the agent—runs the
same public, hidden and lint commands afterward. Record pass/fail, wall time, turns,
tool calls and tokens where the runner exposes them. Do not rank an agent when its
runner failed before it could edit the fixture; report that as infrastructure error.

Diff similarity to gold is not a score. Alternative implementations pass when they
satisfy the observable contracts, quality oracle and safety policy. Gold is used to
prove that the task and oracle are solvable and internally consistent.

An analysis scenario requires complete requirement coverage, exact evidence and a
hidden structural/content oracle. `BLOCKED`, budget exhaustion and missing evidence
are failures, even when a hidden behavior check happens to pass.

## Coverage matrix

| Track | Initial scenario | Primary oracle |
|---|---|---|
| Java | bugfix, refactor, Spring multi-file change | Maven/JUnit hidden tests |
| Kotlin | service feature and Java interop regression | Gradle/JUnit hidden tests |
| Python | feature, bugfix and deterministic testing | pytest public + hidden |
| Rust | ownership-safe feature and error-path bugfix | cargo test hidden module |
| Frontend | TypeScript component behavior | DOM tests + typecheck |
| HTML/CSS | semantic/accessibility/responsive repair | parser, a11y and style assertions |
| Testing | add missing boundary/regression coverage | mutation/seeded-defect detection |
| Analysis | requirements-to-code/test compliance | hidden traceability assertions |
| JSON/XML | schema-preserving transformation | schema + semantic assertions |
| BPMN | process compliance and missing-flow analysis | XML structure + domain rules |
| Jenkins | safe pipeline repair | parser/lint + stage/policy assertions |
| Spring Data | SQL/JPA/Hibernate feature, bugfix and transaction repair | H2 integration + hidden SQL/query/rollback assertions |
| Android | Kotlin feature, resources and manifest repair | Gradle unit tests + Android lint + optional instrumentation |

Each language track is crossed with task roles rather than represented by one
happy-path example: `feature`, `bugfix`, `refactor`, `test`, `release` and
`system-analysis`. Repository/tooling fixtures cover Maven, Gradle, Dockerfile,
Compose, PowerShell and Jenkins. Artifact oracles cover source/classes/imports,
YAML, JSON, XML, HTML/CSS, text/Markdown and BPMN. A row is marked implemented
only when its clean fixture, reviewed gold patch, public check, hidden oracle and
lint/static-analysis command all execute on Windows; file discovery alone is not
coverage.

Add tracks one at a time. A track enters regular regression only after its fixture,
public checks and hidden oracle are deterministic on Windows.

JVM qualification uses Temurin JDK 21 as the preferred toolchain. Spring Boot is
tested as three isolated compatibility families: Boot 3 first (primary production
baseline), Boot 4 second (forward compatibility), and Boot 2 third (legacy
maintenance). Their dependency/API expectations must never be mixed in one oracle.

## Token policy

- Default complex-run ceiling: 80k total model tokens.
- Record input, output, duration, turns, repairs and final runtime state per scenario.
- Compare models on verified completions per token, not raw pass count alone.
- Run a small smoke subset on every change; run the full language/role matrix for a
  release candidate.
- Do not repeat a failed live scenario until code, prompt, tool policy or model changed.

## Reuse references

- Aider: editing strategy, compact repository maps and benchmark methodology.
- Cline: tool ergonomics, IDE feedback and small durable project-memory patterns.
- OpenHands: runtime boundaries, retries, sandbox abstractions and telemetry.
- LSDA: deterministic orchestration, constraints, memory, SDD traceability and DONE.

These are design references, not runtime dependencies. Adopt an idea only when the
same hidden-oracle suite shows a completion, safety or token-efficiency gain.
