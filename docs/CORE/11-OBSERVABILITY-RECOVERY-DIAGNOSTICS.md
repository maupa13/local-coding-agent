# Observability, Recovery and Diagnostics

## Live console

Show:
- state;
- role;
- current step;
- model;
- token counts;
- budget remaining;
- tool;
- progress signal;
- verification status.

## Metrics

Persist:
- model calls;
- input/output tokens;
- tool calls;
- shell calls;
- files read;
- files written;
- tests;
- repair cycles;
- fallback count;
- no-progress events;
- duration;
- final status.

## Logging

Levels:
- ERROR
- WARN
- INFO
- DEBUG
- TRACE

Secret redaction always applies.

## Crash recovery

Persist enough state after every critical action.

On restart:
```text
detect incomplete run
→ verify lock
→ verify repository hashes
→ verify journal
→ reconstruct state
→ continue / inspect / abandon
```

## Abandon

Do not discard user work.

Remove only agent-owned transient state unless user explicitly requests rollback.

## Doctor

`agent-doctor -Deep` should check:
- installed runtime version;
- profile/module health;
- Ollama;
- selected model;
- behavioral compatibility;
- disk space;
- Git;
- Java/build tooling;
- project permissions;
- locks;
- evidence directory;
- memory/index health.

## Diagnostic reports

Failure report includes:
- state;
- failure class;
- last progress;
- model;
- relevant configuration;
- bounded log excerpts;
- evidence path.

## Error classes

- MODEL_ERROR
- TOOL_ERROR
- BUILD_ERROR
- TEST_FAILURE
- PERMISSION_DENIED
- CONTEXT_ERROR
- ENVIRONMENT_ERROR
- USER_CONFLICT
- BUDGET_EXHAUSTED
- INTERNAL_ERROR

Fallback depends on error class.
