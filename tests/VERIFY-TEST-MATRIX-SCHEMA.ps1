[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$matrix=Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw | ConvertFrom-Json
$required=@('id','area','description','test','tier')

foreach($c in @($matrix.contracts)){
  foreach($field in $required){
    if($null -eq $c.PSObject.Properties[$field]){
      throw "[FAIL] $($c.id) missing required schema field: $field"
    }
  }
}

$reg20=@($matrix.contracts|Where-Object{$_.id -eq 'REG-020'})
if($reg20.Count -ne 1){throw '[FAIL] REG-020 must exist exactly once'}
if($reg20[0].tier -ne 'regression'){throw '[FAIL] REG-020 tier mismatch'}
if($reg20[0].test -ne 'tests/VERIFY-EMPTY-CAPTURE-RECOVERY.ps1'){throw '[FAIL] REG-020 test path mismatch'}

Write-Host '[PASS] canonical test-matrix schema for every contract' -ForegroundColor Green
Write-Host '[PASS] REG-020 canonical schema' -ForegroundColor Green
Write-Host 'Test matrix schema regression PASS' -ForegroundColor Cyan
