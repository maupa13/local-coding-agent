/# MASTER SPECIFICATION
## Local Software Delivery Agent (LSDA)

Version: 2.0-draft  
Implementation base: existing Local Coding Agent 1.x  
Primary environment: Windows 11 + IntelliJ IDEA + Git repository  
Primary hardware target: 12 GB VRAM / 32 GB RAM / NVMe  
Primary inference: local Ollama-compatible model  
Primary development method: Specification-Driven Development  
Primary user: one person covering DEV / PO / BA / SA / QA responsibilities

---

## 1. Mission

Build a local-first engineering orchestrator that reliably converts a software task
into a verified repository result.

LSDA is not primarily:
- autocomplete;
- IDE chat;
- a generic chatbot;
- an unconstrained autonomous agent.

LSDA is:

```text
Task
→ deterministic orchestration
→ bounded local reasoning
→ repository change
→ verification
→ repair
→ review
→ evidence
→ DONE / BLOCKED
```

---

## 2. Core Problem

Small local models can understand code yet fail as autonomous workers because they:
- analyse indefinitely;
- repeatedly read the same files;
- fail to write;
- fail to verify;
- prematurely claim success;
- forget earlier decisions;
- overflow context;
- retry identical failures;
- consume excessive tokens;
- corrupt user changes when rollback is unsafe.

LSDA SHALL solve these primarily in runtime software rather than through larger prompts.

---

## 3. Runtime / Model Separation

The deterministic runtime owns:
- state machine;
- persistent memory;
- artifact graph;
- repository index;
- task graph;
- context selection;
- budgets;
- progress detection;
- permissions;
- safe writes;
- verification;
- Definition of Done;
- evidence;
- crash recovery.

The LLM owns:
- bounded interpretation;
- bounded reasoning;
- code generation;
- repair hypotheses;
- architecture proposals;
- review findings.

The model SHALL NOT be the source of truth for state.

---

## 4. First Stable Product Scope

Mandatory:
1. native local model runtime;
2. explicit state machine;
3. progress watchdog;
4. action/step limits;
5. fallback hierarchy;
6. project memory;
7. context minimization;
8. safe change journal;
9. verification and repair;
10. runtime Definition of Done;
11. metrics/evidence;
12. crash recovery;
13. project locking;
14. FAST / NORMAL / DEEP modes;
15. behavioral model compatibility detection.

Later:
- BA role;
- SA/Architect role;
- independent QA;
- richer SDD workflows.

---

## 5. Core States

```text
NEW
→ UNDERSTAND
→ INVESTIGATE
→ PLAN
→ IMPLEMENT
→ VERIFY
→ REPAIR
→ REVIEW
→ DONE
```

Exceptional:
- BLOCKED
- FAILED
- CANCELLED
- RECOVERING

The runtime SHALL reject illegal transitions.

---

## 6. DONE Is Deterministic

For implementation tasks:

```text
DONE =
requested behavior satisfied
AND expected repository changes exist
AND verification executed
AND verification passed
AND required regression passed
AND no forbidden repository operation occurred
AND evidence is complete
```

The LLM cannot authorize DONE.

---

## 7. Atomic Unit

The atomic unit is a cohesive behavior-oriented Change Set.

A Change Set may span multiple files.

Do NOT enforce `one task = one file`.

---

## 8. Memory Principle

Do NOT keep long-term project state in conversation history.

Persist structured knowledge:
- project technology;
- build commands;
- module map;
- accepted architecture decisions;
- requirements;
- acceptance criteria;
- conventions;
- known tests;
- recent completed change summaries.

Memory must be:
- source-attributed;
- versioned;
- invalidatable;
- compact.

---

## 9. Context Principle

Each LLM request receives only context needed for the current step.

Do not send:
- entire repository;
- full run history;
- all specifications;
- full logs;
- unrelated memory.

Context SHALL be rebuilt from deterministic state.

---

## 10. Resource Principle

VRAM is for inference.
RAM and SSD are for:
- indexes;
- parsed artifacts;
- state;
- memory;
- logs;
- evidence;
- repository metadata.

Prefer one loaded model by default on 12 GB VRAM.

---

## 11. Token Principle

Tokens are a paid resource even when inference is local.

Optimize:
- verified completion per token;
- implementation benefit per implementation token;
- context reuse;
- short deterministic prompts;
- bounded retry.

---

## 12. Reuse-First Principle

Reuse mature components where possible:
- Git;
- Ollama;
- Maven/Gradle;
- JUnit/Testcontainers;
- tree-sitter or language indexes when justified;
- JSON/YAML/XML libraries;
- standard filesystem APIs.

Do not build:
- custom Git;
- custom compiler;
- custom LLM server;
- custom IDE;
unless later justified by measurable necessity.

---

## 13. Product Milestone 1

Prove:

> A local model can receive a real coding task, modify the repository, run real
> verification, recover from bounded failure, and finish with evidence without
> endless analysis or false DONE.

Only after this benchmark passes should multi-role orchestration expand.

---

## 14. Required Milestone 1 Acceptance

- real repository write occurs for implementation tasks;
- no-progress loops are detected;
- repeated identical actions stop;
- model cannot self-declare DONE;
- verification is mandatory;
- failed verification causes bounded repair;
- repeated failure becomes BLOCKED;
- user changes are preserved;
- evidence is persisted;
- token metrics are persisted;
- interrupted run can recover;
- model compatibility is behaviorally verified.

---

## 15. Specification Modularity

Implementation agents MUST NOT be asked to read every LSDA specification by default.

The task dispatcher SHOULD provide:
- master spec;
- one or two relevant subsystem specs;
- concrete task;
- relevant existing source files.

This is a product-development token optimization requirement.
