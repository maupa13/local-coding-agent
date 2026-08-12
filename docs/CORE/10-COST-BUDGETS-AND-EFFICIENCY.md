# Cost, Token Budgets and Efficiency

## Two token budgets

### A. Runtime tokens
Tokens consumed by the finished product.

### B. Implementation tokens
Tokens consumed while agents implement LSDA itself.

Both matter.

## Runtime efficiency KPI

```text
Verified completions / model tokens
```

Useful secondary:
- median tokens per completed task;
- P95 tokens;
- tokens per repair;
- tokens wasted before NO_PROGRESS.

## Implementation efficiency KPI

```text
Benchmark gain / implementation token spend
```

Do not require a perfect mathematical formula; track enough data for decisions.

## Feature classification

Each feature:
- BUILD_NOW;
- REUSE;
- ADAPT;
- DEFER;
- REJECT.

## Rules for coding agents implementing LSDA

- reuse current Local Coding Agent modules;
- no broad rewrite without necessity;
- no style-only refactor;
- no speculative abstraction;
- small cohesive change sets;
- bounded repair;
- regression required;
- do not implement deferred features early.

## Modes

FAST:
- small context;
- few turns;
- focused verification.

NORMAL:
- standard budgets;
- affected regression.

DEEP:
- larger context;
- architecture/review/full regression when justified.

## Budget exhaustion

On exhaustion:
- stop cleanly;
- persist state;
- produce partial result;
- return BLOCKED/BUDGET_EXHAUSTED;
- allow explicit continuation.

## Cache/reuse

Where supported:
- keep stable system instructions stable;
- avoid repeating unchanged large context;
- reuse project indexes;
- reuse project memory.

## Stop/Go rule

If a feature costs substantial implementation tokens and does not improve:
- completion;
- safety;
- cost;
- recoverability;
it should be deferred or removed.
