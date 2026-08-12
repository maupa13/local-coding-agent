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

Add tracks one at a time. A track enters regular regression only after its fixture,
public checks and hidden oracle are deterministic on Windows.

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
