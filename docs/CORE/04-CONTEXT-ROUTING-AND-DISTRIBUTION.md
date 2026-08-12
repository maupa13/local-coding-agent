# Context Routing and Distribution

## 1. Goal

Use deterministic context selection to compensate for small local model context and reasoning limits.

## 2. Context Builder Inputs

Potential sources:
- task;
- acceptance criteria;
- current state;
- relevant project memory;
- relevant source files;
- symbol references;
- current diff;
- latest test/build failure;
- architecture constraints.

## 3. Priority

1. explicit user request;
2. acceptance criteria;
3. current Change Set;
4. target symbols;
5. directly dependent contracts;
6. latest failure evidence;
7. nearby tests;
8. architecture rules;
9. broader repository metadata.

## 4. Context Is Step-Specific

UNDERSTAND:
- task;
- compact project facts.

INVESTIGATE:
- repository map;
- search results;
- candidate files.

IMPLEMENT:
- requirements;
- target sources;
- interfaces;
- tests.

VERIFY:
- command;
- diff summary;
- errors.

REPAIR:
- failure fingerprint;
- relevant source;
- current patch.

REVIEW:
- requirements;
- diff;
- test evidence;
- architecture constraints.

## 5. Distribution Across Roles

Do not share a huge conversation between roles.

Use artifact handoff:

```text
BA output → requirement artifact
SA output → architecture artifact
DEV output → diff + verification
QA input → requirements + diff + evidence
Reviewer input → requirements + diff + evidence
```

## 6. Context Caps

Caps SHOULD be dynamic by model/mode.

Example initial targets:

```yaml
FAST:   3k-5k input tokens
NORMAL: 5k-10k
DEEP:   8k-16k
```

These are tuning targets, not correctness guarantees.

## 7. Large File Handling

For large files:
- locate relevant symbols;
- extract bounded sections;
- include imports/contracts as required;
- avoid blind truncation from file beginning.

## 8. Log Handling

Send:
- error type;
- message;
- relevant stack frames;
- source location;
- exit code.

Persist full logs separately.

## 9. Acceptance

- same large repository task can execute without full repo context;
- repeated calls avoid resending irrelevant data;
- role handoff works through artifacts, not long chat history;
- repair context is smaller than original implementation context where possible.
