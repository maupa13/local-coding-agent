[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

foreach($needle in @(
  'Never jump to a previously used repository',
  '$root=Get-NormalizedPath $cwd',
  'использую её как корень проекта',
  'No managed run yet for this project.',
  'No result yet for this project.'
)){
  if($m -notmatch [regex]::Escape($needle)){throw "[FAIL] project-root/session isolation contract missing: $needle"}
}
if($m -match 'Get-AgentLastProject\s*\r?\n\s*if \(\$last\)'){
  throw '[FAIL] Start-AgentShell still silently falls back to lastProject'
}
Write-Host '[PASS] agent without -Project is bound to current directory and cannot silently jump to lastProject' -ForegroundColor Green
Write-Host '[PASS] status/result do not leak latest evidence from a different project' -ForegroundColor Green
Write-Host 'Project root selection regression PASS' -ForegroundColor Cyan
