# Runtime State Machine

## Goal

Replace free-form autonomous loops with explicit lifecycle control.

## Required states

- NEW
- UNDERSTAND
- INVESTIGATE
- PLAN
- IMPLEMENT
- VERIFY
- REPAIR
- REVIEW
- DONE
- BLOCKED
- FAILED
- CANCELLED
- RECOVERING

## Core transitions

```text
NEW → UNDERSTAND
UNDERSTAND → INVESTIGATE
INVESTIGATE → PLAN
PLAN → IMPLEMENT
IMPLEMENT → VERIFY
VERIFY(pass) → REVIEW
VERIFY(fail) → REPAIR
REPAIR → VERIFY
REVIEW(pass) → DONE
REVIEW(fail) → REPAIR
```

## Runtime authority

The runtime validates all transitions.

The LLM can request:
- continue;
- verify;
- blocked;
- repair.

It cannot directly set persistent state.

## Persisted state

At minimum:
- run ID;
- task ID;
- task type;
- state;
- current change set;
- current role;
- turn counters;
- tool counters;
- repair counters;
- budget use;
- changed files;
- verification status;
- blockers;
- model identifier;
- timestamps.

## Task types

- QUESTION
- ANALYSIS
- DOCUMENTATION
- IMPLEMENTATION
- TESTING
- REVIEW
- RELEASE
- SDD_INITIATIVE

Each has a different DONE contract.

## Crash behavior

State should be persisted after:
- state transition;
- write;
- shell verification;
- fallback escalation;
- model change;
- result generation.

## Acceptance

- illegal transitions rejected;
- state survives process restart;
- incomplete runs detected;
- verification failure cannot become DONE;
- runtime can reconstruct the next allowed action.
