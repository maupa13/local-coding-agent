# LSDA Specification Pack v2

This package defines the next evolution of the existing Local Coding Agent into a
local-first Software Delivery / Engineering Orchestrator.

The package is intentionally modular. Do NOT feed every specification to an LLM for
every task.

## Recommended loading rules

Always load:
- `00-MASTER-SPEC.md`

Then load only relevant modules.

### Runtime / endless-analysis work
- `01-RUNTIME-STATE-MACHINE.md`
- `02-PROGRESS-LIMITS-FALLBACK.md`

### Memory / context work
- `03-MEMORY-CONTEXT-ARTIFACTS.md`
- `04-CONTEXT-ROUTING-AND-DISTRIBUTION.md`

### Model / hardware / inference work
- `05-MODEL-ROUTING-AND-RESOURCES.md`

### Repository writes / permissions / rollback
- `06-SAFE-CHANGES-PERMISSIONS-CONCURRENCY.md`

### Verification / DONE / evidence
- `07-VERIFICATION-DONE-EVIDENCE.md`

### SDD / roles / requirements / architecture
- `08-SDD-ROLES-AND-TRACEABILITY.md`

### Testing / benchmarks
- `09-TESTING-BENCHMARKS.md`

### Token / implementation cost
- `10-COST-BUDGETS-AND-EFFICIENCY.md`

### Observability / recovery / diagnostics
- `11-OBSERVABILITY-RECOVERY-DIAGNOSTICS.md`

### Packaging / release
- `12-INSTALL-UPGRADE-RELEASE.md`

### Implementation order
- `13-IMPLEMENTATION-ROADMAP.md`

## Design rule

The system must keep deterministic state outside the LLM.
The model receives only the context required for the current atomic reasoning step.

The first objective is not full PO/BA/SA automation.
The first objective is reliable verified coding completion with small local models.
