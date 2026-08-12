# Memory, Context and Artifact Storage

## 1. Memory Layers

LSDA SHALL distinguish:

### L0 — Ephemeral Turn Context
Exists only for one model call.

Contains:
- current instruction;
- current evidence;
- current source excerpts.

### L1 — Run Memory
Lives for current run.

Contains:
- task state;
- decisions;
- current Change Set;
- recent failure summaries;
- current verification.

### L2 — Project Memory
Persists between runs.

Contains only durable project facts:
- stack;
- modules;
- build/test commands;
- architectural conventions;
- repository policies;
- accepted ADR summaries;
- relevant domain vocabulary.

### L3 — Delivery Artifacts
Authoritative persistent outputs:
- requirements;
- architecture;
- task/change set;
- traceability;
- evidence;
- release reports.

## 2. Do Not Persist Raw Reasoning

Do not store long hidden/model reasoning as durable project memory.

Persist:
- decisions;
- evidence;
- compact summaries;
- sources.

## 3. Memory Record

Example:

```yaml
id: MEM-ARCH-001
kind: architecture
statement: REST controllers must not access repositories directly.
source:
  type: file
  path: docs/architecture.md
source_hash: ...
created_at: ...
confidence: high
invalidates_when:
  - docs/architecture.md changes
```

## 4. Memory Invalidation

Memory derived from files SHALL be invalidated when source hashes change.

Memory derived from user decisions SHALL remain until explicitly superseded.

## 5. Repository Knowledge Index

Persist compact indexes:
- file tree;
- module graph;
- detected languages;
- symbols if available;
- test locations;
- dependency manifests;
- build files.

Do not persist full copies of repository files in memory unless required for evidence.

## 6. Artifact Store

Recommended:

```text
.lsda/
  project.json
  memory/
  indexes/
  requirements/
  architecture/
  runs/
  locks/
```

## 7. Run Compaction

When run context becomes large:
1. summarize completed decisions;
2. preserve unresolved items;
3. preserve latest diff and failure evidence;
4. discard repetitive tool chatter from active context;
5. retain raw transcript only in evidence.

## 8. Memory Retrieval

Retrieve memory by:
- task type;
- affected module;
- relevant symbol;
- explicit requirement;
- architecture tag.

Do not inject all project memory into every prompt.

## 9. Acceptance

- run can continue after conversation history is flushed;
- durable project facts survive restart;
- stale source-derived memory invalidates;
- task prompts receive only relevant memory;
- raw reasoning is not treated as authoritative state.
