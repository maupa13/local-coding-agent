[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dev=Get-Content -LiteralPath (Join-Path $root 'DEV.ps1') -Raw
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$config=Get-Content -LiteralPath (Join-Path $root 'config\config-agent.yaml') -Raw
$smoke=Get-Content -LiteralPath (Join-Path $root 'tests\RUN-CONTINUE-TOOL-SMOKE.ps1') -Raw

if($config -notmatch '(?m)^\s{4}reasoning:\s*false\s*$'){throw '[FAIL] base agent config does not disable reasoning'}
if($config -match '(?m)^experimental:\s*$'){throw '[FAIL] unsupported top-level experimental YAML block present'}
if($module -notmatch 'reasoning:\s*false'){throw '[FAIL] runtime config generator does not force reasoning false'}
if($dev -notmatch 'RUN-CONTINUE-TOOL-SMOKE\.ps1'){throw '[FAIL] DEV install does not execute real Continue tool smoke'}
if($smoke -notmatch '-C\s+\$tmp\s+init'){throw '[FAIL] real tool smoke does not initialize its project fixture as a Git repository'}
foreach($tool in @('Edit','MultiEdit','Write')){
  if($smoke -notmatch "(?s)'--allow'\s*,\s*'$([regex]::Escape($tool))'"){
    throw "[FAIL] real tool smoke lacks explicit headless $tool permission"
  }
}
if($smoke -notmatch 'DID NOT EDIT main\.md'){throw '[FAIL] real tool smoke does not fail closed when cn exits 0 without editing'}
Write-Host '[PASS] reasoning disabled for managed model/tool path' -ForegroundColor Green
Write-Host '[PASS] install is gated by a real cn file-edit smoke' -ForegroundColor Green
Write-Host 'Model tool gate regression PASS' -ForegroundColor Cyan
