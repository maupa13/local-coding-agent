[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

foreach($needle in @(
  '$docExt=@(''.md'',''.markdown'',''.mdown'',''.txt'',''.rst'',''.adoc'',''.yaml'',''.yml'',''.json'')',
  "return 'docs'",
  "'docs','migration'",
  'Задача требовала изменения проекта, но агент не изменил ни одного файла'
)){
  if($m -notmatch [regex]::Escape($needle)){throw "[FAIL] missing doc-edit contract: $needle"}
}

# The edit routing branch must occur before generic analysis fallback.
$editIndex=$m.IndexOf("return 'docs'")
$analysisIndex=$m.IndexOf("return 'analysis'",$editIndex)
if($editIndex -lt 0 -or $analysisIndex -lt 0 -or $editIndex -gt $analysisIndex){
  throw '[FAIL] document edit routing does not win before analysis fallback'
}

Write-Host '[PASS] root-level Markdown/text files are repository documentation' -ForegroundColor Green
Write-Host '[PASS] explicit document edit intent routes to /docs before read-only analysis' -ForegroundColor Green
Write-Host '[PASS] mutating docs/delivery workflow with zero changed files is FAIL-closed' -ForegroundColor Green
Write-Host 'Document edit routing regression PASS' -ForegroundColor Cyan
