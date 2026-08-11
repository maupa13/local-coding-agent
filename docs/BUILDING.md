# Building

Requirements: Windows PowerShell 5.1, Git, Ollama for live evaluation, and the build
tools required by fixture languages.

```powershell
.\build.ps1 -Clean
```

The build performs source validation, deterministic tests, staging, clean-process module
import, ZIP creation and SHA256 generation. Output is written to `artifacts/`.

`-SkipTests` exists only for local packaging diagnostics and is not release-qualified.

