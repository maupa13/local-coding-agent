[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$qualify=Get-Content -LiteralPath (Join-Path $root 'QUALIFY-RELEASE.ps1') -Raw
$live=Get-Content -LiteralPath (Join-Path $root 'tests\RUN-LIVE-E2E.ps1') -Raw
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

function Need([string]$Text,[string]$Pattern,[string]$Name){
  if($Text -notmatch $Pattern){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

Need $qualify 'Start-Transcript' 'qualification persistent transcript'
Need $qualify 'Environment snapshot' 'qualification environment snapshot'
Need $qualify '\[STEP\] exit:' 'qualification step exit/timing'
Need $live 'function Write-EvidenceDiagnostics' 'live E2E evidence dumper'
Need $live 'compliance-requirements-diagnostic\.txt' 'live E2E prints requirement diagnostics'
Need $live 'model-output\.txt' 'live E2E prints model output'
Need $live 'compliance-recovery-output\.txt' 'live E2E prints recovery output'
Need $live 'session\.json' 'live E2E prints session metadata'
Need $live 'Fixture preserved automatically after failure' 'failed fixture is preserved'
Need $module 'RepositoryRoot exists:' 'compliance extractor logs repository root'
Need $module 'DocsRoot exists:' 'compliance extractor logs docs root'
Need $module 'requirement matches:' 'compliance extractor logs regex matches'
Need $module 'Unique requirements:' 'compliance extractor logs final count'
Write-Host 'Diagnostic logging contract PASS' -ForegroundColor Cyan
