# Extending

## Provider

Add a provider adapter as a separate file under `powershell/Providers/`, expose one
internal invocation contract, and add deterministic parsing/error/timeout tests plus at
least one hidden model eval. Do not add provider logic to command routing.

## Tool

Document its arguments, repository boundary, mutation class and error contract. Add
tests for success, denial, path traversal and non-zero native exit status.

## Workflow

Add the prompt contract and catalog entry. Routing, permission mode, expected mutations
and deterministic verification must be declared independently of the model prompt.

## Language

Add detection plus build/test command discovery and an external hidden oracle fixture.
The model's own test is useful evidence but cannot be the only acceptance check.
