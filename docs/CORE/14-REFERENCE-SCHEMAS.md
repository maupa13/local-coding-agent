# Reference Schemas

## Run state

```json
{
  "runId": "RUN-...",
  "taskType": "IMPLEMENTATION",
  "state": "VERIFY",
  "mode": "NORMAL",
  "model": "qwen-local",
  "turns": 8,
  "toolCalls": 17,
  "repairCycles": 1,
  "budget": {
    "inputTokens": 12000,
    "outputTokens": 2400
  }
}
```

## Change Set

```json
{
  "id": "CS-001",
  "requirements": ["REQ-001"],
  "acceptance": ["AC-001"],
  "files": [],
  "symbols": [],
  "verification": []
}
```

## Memory

```json
{
  "id": "MEM-001",
  "kind": "project-convention",
  "statement": "Use Maven Wrapper for verification.",
  "source": {
    "type": "file",
    "path": "README.md",
    "hash": "..."
  },
  "confidence": "high"
}
```

## Change journal

```json
{
  "runId": "RUN-001",
  "path": "src/main/java/Example.java",
  "beforeSha256": "...",
  "afterSha256": "...",
  "operation": "replace"
}
```

## Verification

```json
{
  "command": ".\\mvnw.cmd test",
  "exitCode": 0,
  "startedAt": "...",
  "finishedAt": "...",
  "summary": "148 tests passed"
}
```

## Result

```json
{
  "status": "DONE",
  "requirements": ["REQ-001"],
  "filesChanged": [],
  "verification": [],
  "risks": [],
  "evidencePath": ".lsda/runs/RUN-001"
}
```
