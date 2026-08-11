[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
Import-Module $modulePath -Force -DisableNameChecking
$m=Get-Module LocalCodingAgent | Select-Object -First 1
if(-not $m){throw '[FAIL] module import failed'}
$tmp=$null

try{
  $route=& $m { Resolve-AgentModeIntent 'отредактируй main.md до статуса полноценной мастер спеки' }
  if($route -ne 'docs'){throw "[FAIL] expected docs route, got '$route'"}
  Write-Host '[PASS] user phrase routes to docs' -ForegroundColor Green

  $improveRoute=& $m { Resolve-AgentModeIntent 'улучши документацию' }
  if($improveRoute -ne 'docs'){throw "[FAIL] expected improve-docs route, got '$improveRoute'"}
  Write-Host '[PASS] improve documentation routes to docs' -ForegroundColor Green

  $tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-doc-journey-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  Set-Content -LiteralPath (Join-Path $tmp 'main.md') -Encoding UTF8 -Value '# Идея'
  $inv=& $m { param($p) Get-AgentRepositoryInventory $p } $tmp
  if(@($inv.Docs) -notcontains 'main.md'){throw '[FAIL] root main.md was not discovered as documentation'}
  Write-Host '[PASS] root main.md is discovered as documentation' -ForegroundColor Green
}finally{
  if($tmp){Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
}
Write-Host 'Document edit user journey PASS' -ForegroundColor Cyan
