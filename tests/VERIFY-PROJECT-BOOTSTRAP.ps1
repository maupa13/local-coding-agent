[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
Import-Module $modulePath -Force -DisableNameChecking
$tmp=$null
try{
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-project-bootstrap-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'src')|Out-Null
  @'
{
  "name": "bootstrap-fixture",
  "scripts": {
    "build": "node build.js",
    "test": "node test.js"
  }
}
'@|Set-Content -LiteralPath (Join-Path $tmp 'package.json') -Encoding UTF8
  'console.log("ok")'|Set-Content -LiteralPath (Join-Path $tmp 'src\index.js') -Encoding UTF8
  agent-init -Project $tmp
  $rulePath=Join-Path $tmp '.continue\rules\00-project.md'
  if(-not(Test-Path -LiteralPath $rulePath)){throw '[FAIL] project rule was not created'}
  $rule=Get-Content -LiteralPath $rulePath -Raw
  foreach($needle in @('Stack detected: Node','npm --prefix','run build','run test','Source files discovered: 1','Dependency manifests and lockfiles require explicit dependency opt-in')){
    if(-not $rule.Contains($needle)){throw "[FAIL] generated rule missing: $needle"}
  }
  Write-Host '[PASS] agent-init generates repository-grounded build/test/safety rules' -ForegroundColor Green
}finally{
  if($tmp){Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
}
Write-Host 'Project bootstrap regression PASS' -ForegroundColor Cyan
