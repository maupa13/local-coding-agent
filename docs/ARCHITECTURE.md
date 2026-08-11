# Architecture

Local Coding Agent is a PowerShell module and product shell around pluggable model
runtimes. Repository paths are resolved from the package root, never from the caller's
current directory.

## Layers

- `powershell/LocalCodingAgent.psd1` defines the supported public API.
- `powershell/LocalCodingAgent.psm1` owns sessions, routing, evidence and quality gates.
- `powershell/OllamaAgentLoop.ps1` is the current local-provider adapter and managed tool loop.
- `powershell/WorkflowState.ps1` enforces delivery status transitions independently of model output.
- `powershell/ArtifactAnalysis.ps1` extracts BPMN, XSD, JSON/Schema/OpenAPI and specification facts for grounded review.
- `config/` contains provider, model and permission policy.
- `workflows/` contains task contracts; it must not contain runtime implementation.
- `tests/` contains deterministic wrapper tests and independent model evaluations.
- `build/` creates the distributable artifact; `artifacts/` is generated output.$diffFiles += @(& git -C $fixture diff
  --name-only --ignore-space-at-line)
  echo "Diff files: $diffFiles"

The current 4,000-line core module is a compatibility boundary, not the desired final
shape. New provider/tool/evaluation code must be added as a separate component and
loaded by the root module. Existing sections will be extracted incrementally with
behavioral tests protecting every move.

## Execution flow

`agent` resolves a project, routes intent to one workflow, snapshots Git state, invokes
the selected provider runtime, records tool/model evidence, runs deterministic checks,
and lets the quality gate override unsupported model claims. Model text alone can never
promote a workflow to PASS.

The delivery lifecycle follows the status/transition/resolution model documented
in `DELIVERY-WORKFLOW.md`. In particular, deterministic verification failure moves
work back to implementation and `Released` requires a hidden evaluation gate.
