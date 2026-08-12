# Progress, Limits and Fallback

## Goal

Prevent token-burning loops where the model appears busy but produces no engineering progress.

## Progress signals

Positive progress:
- new repository diff;
- test/build execution;
- new relevant failure evidence;
- reduced failing tests;
- new accepted requirement decision;
- blocker proven with evidence;
- artifact generated;
- architecture question resolved.

## No-progress examples

```text
read → search → read → search → read
```

with:
- no changed file;
- no verification;
- no new evidence;
- no new decision.

## Recommended defaults

```yaml
max_agent_turns: 20
max_tool_calls: 50
max_shell_calls: 15
max_write_calls: 15
max_repair_cycles: 3
max_recovery_attempts: 3
max_consecutive_errors: 5
max_same_action_repeats: 3
max_analysis_only_turns: 3
max_read_only_turns_for_implementation: 6
max_no_progress_turns: 5
max_same_failure_signature: 2
```

## Progress watchdog

Track:
- last meaningful progress step;
- current diff hash;
- last failure fingerprint;
- last commands;
- repeated reads;
- repeated search terms.

## Fallback ladder

### F1 — Force Action
Model must choose:
- change;
- verification;
- BLOCKED.

### F2 — Rebuild Context
Discard stale conversational history.

### F3 — Change Tool Strategy
Switch from broad analysis to focused symbol/file/test evidence.

### F4 — Reduced Task
Split Change Set only if cohesion allows it.

### F5 — Alternate Model
Optional, bounded, benchmarked.

### F6 — BLOCKED
Stop token consumption.

## Rules

Fallback does NOT reset global budgets.

The same failed fallback cannot repeat indefinitely.

## Acceptance

- endless analysis interrupted;
- repeated tool sequences detected;
- repeated identical test without changed input detected;
- same failure signature escalates;
- final BLOCKED contains evidence and suggested human action.
