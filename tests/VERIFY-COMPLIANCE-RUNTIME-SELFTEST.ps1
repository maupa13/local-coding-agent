[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tempRoot=Join-Path ([System.IO.Path]::GetTempPath()) ('LocalCodingAgent-compliance-selftest-'+[guid]::NewGuid().ToString('N'))
$diag=Join-Path $tempRoot 'requirements-diagnostic.txt'
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'

try{
  & (Join-Path $root 'tests\NEW-RELEASE-E2E-REPO.ps1') -Path $tempRoot
  if(-not(Test-Path -LiteralPath (Join-Path $tempRoot 'docs\requirements.md'))){
    throw '[FAIL] release fixture requirements.md missing'
  }

  $m=Import-Module $modulePath -Force -DisableNameChecking -PassThru
  if(-not $m){throw '[FAIL] LocalCodingAgent module import failed'}

  $requirements=[object[]](Test-LocalCodingAgentComplianceExtractor -ProjectRoot $tempRoot -DiagnosticPath $diag)

  $ids=@($requirements|ForEach-Object{[string]$_.Id}|Sort-Object -Unique)
  Write-Host "[INFO] runtime requirement IDs: $($ids -join ', ')" -ForegroundColor DarkGray
  Write-Host "[INFO] runtime diagnostic: $diag" -ForegroundColor DarkGray

  $expected=@('REQ-01','REQ-02','REQ-03','REQ-04')
  $missing=@($expected|Where-Object{$ids -notcontains $_})
  if($missing.Count){
    Write-Host '[DIAGNOSTIC] requirement extraction failed:' -ForegroundColor Yellow
    if(Test-Path -LiteralPath $diag){
      Get-Content -LiteralPath $diag|ForEach-Object{Write-Host ("  "+$_)}
    }
    throw "[FAIL] runtime compliance extractor missing: $($missing -join ', ')"
  }
  if($ids.Count -ne 4){
    Write-Host "[WARN] unexpected additional requirement IDs: $($ids -join ', ')" -ForegroundColor Yellow
  }

  Write-Host '[PASS] runtime compliance extractor returned REQ-01..REQ-04 under current Windows PowerShell' -ForegroundColor Green
  Write-Host 'Compliance runtime self-test PASS' -ForegroundColor Cyan
}catch{
  Write-Host ("[FAIL] runtime extractor exception: " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message) -ForegroundColor Red
  if(Test-Path -LiteralPath $diag){
    Write-Host '[DIAGNOSTIC] extractor trace:' -ForegroundColor Yellow
    Get-Content -LiteralPath $diag -ErrorAction SilentlyContinue|ForEach-Object{Write-Host ("  "+$_)}
  }
  throw
}finally{
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
