# Implementation Roadmap

This order is designed to minimize implementation token waste.

## Phase 0 — Freeze and Benchmark

Do:
- preserve current Local Coding Agent;
- create benchmark fixtures;
- record baseline behavior;
- record token usage.

GO only when benchmark is repeatable.

## Phase 1 — State Machine + DONE

Implement:
- explicit states;
- transition guards;
- task type contracts;
- runtime-computed DONE.

GO:
- false DONE impossible in tests.

## Phase 2 — Progress + Limits

Implement:
- no-progress watchdog;
- repeated action detection;
- budgets;
- fallback F1-F3;
- BLOCKED.

GO:
- endless analysis reliably stops.

## Phase 3 — Memory + Context

Implement:
- run memory;
- project memory;
- source hash invalidation;
- compact artifact store;
- step-specific context builder.

GO:
- resumed task succeeds without replaying full history;
- context/token usage measurably reduced.

## Phase 4 — Safe Changes

Implement:
- change journal;
- atomic writes;
- user-change preservation;
- project lock;
- secret redaction.

GO:
- zero lost user changes in regression.

## Phase 5 — Verification + Recovery

Implement:
- bounded repair;
- failure fingerprints;
- crash recovery;
- evidence reconstruction.

GO:
- interrupted task resumes safely.

## Phase 6 — Model / Resource Routing

Implement:
- behavioral compatibility probe;
- selected model state;
- bounded fallback;
- resource diagnostics.

GO:
- incompatible model rejected before real project damage.

## Phase 7 — FAST / NORMAL / DEEP

Implement:
- per-mode context and step budgets;
- mode-specific verification policy.

GO:
- FAST costs less and retains minimum correctness gates.

## Phase 8 — Independent Quality

Try one first:
- Reviewer OR QA.

Measure token overhead and defect detection.

GO only if measurable benefit.

## Phase 9 — SDD Expansion

Add:
- requirement IDs;
- acceptance;
- traceability;
- BA;
- SA/Architecture.

Only after coding loop is reliable.

## Phase 10 — UX / Release Hardening

Improve:
- IDEA workflow;
- console clarity;
- diagnostics;
- installer;
- qualification.

## Absolute rule

No new phase before previous phase has:
- implementation;
- regression tests;
- benchmark;
- explicit GO.
