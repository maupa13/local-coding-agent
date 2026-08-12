# Model Routing and Resource Distribution

## 1. Target

Primary hardware:
- GPU VRAM <= 12 GB;
- RAM >= 32 GB;
- NVMe SSD.

## 2. Resource Roles

VRAM:
- active model weights;
- KV cache;
- inference.

RAM:
- parsers;
- indexes;
- runtime state;
- test processes;
- context assembly.

SSD:
- model storage;
- Git repository;
- evidence;
- project memory;
- indexes;
- checkpoints.

## 3. Default Model Strategy

Prefer one loaded model to avoid reload cost and VRAM churn.

Use separate models only when benchmark demonstrates benefit.

## 4. Behavioral Compatibility

Model metadata is insufficient.

A model SHALL pass a behavioral capability probe:
1. understand a bounded task;
2. request/use expected tool flow;
3. produce an actual edit;
4. respond to failure;
5. finish with required structured result.

## 5. Model Profiles

Possible profiles:

```yaml
coding:
  required: edit capability
review:
  required: defect detection
fast:
  required: low latency
```

Initially these MAY all map to one model.

## 6. Routing

Routing SHALL consider:
- task type;
- execution mode;
- measured model capabilities;
- remaining token budget;
- current model availability.

## 7. Fallback Model

Optional secondary model.

Fallback triggers:
- repeated malformed action;
- repeated identical failure;
- capability mismatch.

Do not fallback simply because a test failed once.

## 8. Model Loading

Avoid frequent load/unload.

Prefer:
- keep-alive;
- serial execution on 12 GB VRAM;
- one active model unless proven otherwise.

## 9. Context Size

Context size SHALL be configurable.

Larger context is not automatically better.

Measure:
- completion;
- tokens;
- latency;
- VRAM use.

## 10. Hardware Safety

Runtime SHOULD detect:
- insufficient disk;
- unreachable Ollama;
- missing model;
- model unload;
- inference timeout;
- GPU OOM where observable.

## 11. Acceptance

- model selection is based on real probes;
- missing selected model is diagnosed;
- fallback is bounded;
- resource policy avoids simultaneous unnecessary model loading;
- agent can recover when configured model disappears between runs.
