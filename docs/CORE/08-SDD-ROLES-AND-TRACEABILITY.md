# SDD, Roles and Traceability

## Strategy

Do not implement all roles before the reliable DEV loop is proven.

## Future roles

- PO
- BA
- SA / Architect
- DEV
- QA
- Reviewer
- Release Manager

These are logical roles and may share one local model.

## Role isolation

State passes through structured artifacts.

Do not maintain one giant multi-role conversation.

## Requirement artifact

Each requirement:
- ID;
- statement;
- source;
- acceptance criteria;
- status.

## BA

Produces:
- actors;
- business rules;
- edge cases;
- requirements;
- acceptance;
- unresolved questions.

## SA / Architect

Produces:
- affected components;
- interfaces;
- contracts;
- data impact;
- integration behavior;
- failure modes;
- ADR when required.

## DEV

Produces:
- cohesive Change Set;
- repository edits;
- verification.

## QA

Receives:
- requirement;
- acceptance;
- diff;
- test evidence.

Produces:
- missing scenarios;
- regression risks;
- test recommendations;
- defects.

## Reviewer

Receives clean context:
- requirement;
- diff;
- architecture constraints;
- evidence.

It should actively search for faults rather than justify implementation.

## Traceability

```text
REQ
→ AC
→ CHANGE SET
→ FILE/SYMBOL
→ TEST
→ RESULT
```

## Expansion gate

Add a role only when benchmark demonstrates quality gain worth its token/runtime overhead.
