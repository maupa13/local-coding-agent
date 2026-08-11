[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$q=Get-Content -LiteralPath (Join-Path $root 'powershell\QUALIFY-RELEASE.ps1') -Raw

if($q -match 'Export-Clixml' -or $q -match 'Import-Clixml'){
  throw '[FAIL] qualification Run-Step still uses CLIXML argument trampoline'
}
if($q -notmatch '& \$exe .* -File \$path @Arguments'){
  throw '[FAIL] qualification Run-Step does not preserve native PowerShell parameter binding'
}
if($q -notmatch '\$code=\$LASTEXITCODE'){
  throw '[FAIL] qualification Run-Step does not use authoritative child exit code'
}
if($q -notmatch 'STEP-\$safeName\.stdout\.log' -or $q -notmatch 'STEP-\$safeName\.stderr\.log'){
  throw '[FAIL] per-step stdout/stderr logs missing'
}
Write-Host '[PASS] qualification Run-Step preserves argument binding and exit code' -ForegroundColor Green
Write-Host 'Qualification argument binding regression PASS' -ForegroundColor Cyan
