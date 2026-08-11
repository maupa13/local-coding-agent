# Delivery workflow

The delivery lifecycle is an executable state machine, not a model prompt.
Its source of truth is `config/work-item-workflows.json`; the enforcement code
is `powershell/WorkflowState.ps1`.

## Lifecycle

`Backlog -> Discovery -> Ready -> Implementation -> Verification -> Review -> ReleaseReady -> Released`

Documentation work uses a shorter scheme, while bugfixes, features and
refactors use the full engineering scheme. `Blocked` is temporary;
`Released` and `Rejected` are terminal resolutions.

Verification or review failure returns the item to `Implementation`. A model
cannot report its way around this transition: the wrapper supplies evidence
gates after inspecting the repository and command exit codes.

## Release gates

- `submit`: production changes and tests exist.
- `verify`: deterministic checks passed.
- `approve`: independent review and stored evidence exist.
- `ship`: build, hidden model evaluation and evidence all passed.

The transition history is append-only within the work-item record and includes
the transition name, source/target status, timestamp and gates used.
