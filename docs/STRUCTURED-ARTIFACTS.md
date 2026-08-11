# Structured artifact analysis

`Invoke-AgentArtifactAnalysis` extracts repository facts before an LLM is
asked to interpret an artifact. Its output is designed for evidence and
compliance matrices rather than free-form summaries.

Supported in the current release candidate:

- BPMN/XML: process count, flow nodes, sequence flows, broken endpoints and
  nodes unreachable from start events.
- XSD: target namespace, top-level elements, simple/complex types,
  imports/includes and missing local `schemaLocation` files.
- JSON, JSON Schema and OpenAPI: parsing, format classification, `$ref`
  inventory and missing external local references.
- Markdown/text specifications: requirement IDs, text and exact source lines.

Example:

```powershell
Import-Module .\powershell\LocalCodingAgent.psd1
Invoke-AgentArtifactAnalysis .\docs\process.bpmn | ConvertTo-Json -Depth 10
```

The parser result is intentionally conservative. Semantic BPMN correctness,
business meaning and cross-document contradictions are reviewed by a model
after deterministic extraction; they are not fabricated by the parser.
