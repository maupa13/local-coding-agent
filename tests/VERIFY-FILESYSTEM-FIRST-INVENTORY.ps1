[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
Import-Module $modulePath -Force -DisableNameChecking
$m=Get-Module LocalCodingAgent|Select-Object -First 1
$tmp=$null
try{
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-fs-inv-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  Set-Content -LiteralPath (Join-Path $tmp 'main.md') -Encoding UTF8 -Value '# spec'
  New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'src')|Out-Null
  Set-Content -LiteralPath (Join-Path $tmp 'src\app.py') -Encoding UTF8 -Value 'print("ok")'
  $inv=& $m {param($p) Get-AgentRepositoryInventory $p} $tmp
  if(@($inv.Docs) -notcontains 'main.md'){throw '[FAIL] main.md missing from Docs'}
  if(@($inv.Sources) -notcontains 'src\app.py'){throw '[FAIL] src\app.py missing from Sources'}
  if(@($inv.Files).Count -ne 2){throw "[FAIL] expected 2 inventory files, got $(@($inv.Files).Count)"}
  Write-Host '[PASS] filesystem inventory discovers root docs and source without Git dependency' -ForegroundColor Green
}finally{
  if($tmp){Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
}
Write-Host 'Filesystem-first inventory PASS' -ForegroundColor Cyan
