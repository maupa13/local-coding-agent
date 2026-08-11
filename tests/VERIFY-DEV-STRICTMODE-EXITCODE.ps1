[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dev=Get-Content -LiteralPath (Join-Path $root 'DEV.ps1') -Raw

if($dev -notmatch 'function Invoke-DevScript'){throw '[FAIL] DEV child-script runner missing'}
if($dev -notmatch '\$script:DevLastExitCode=0'){throw '[FAIL] DEV exit-code state is not initialized under StrictMode'}
if($dev -notmatch '& \$powershellExe .* -File \$ScriptPath @Arguments'){throw '[FAIL] DEV scripts are not executed in an isolated native PowerShell child'}
if($dev -notmatch '\$script:DevLastExitCode=\[int\]\$LASTEXITCODE'){throw '[FAIL] DEV child native exit code is not captured'}
if($dev -match '& \(Join-Path \$root ''VERIFY-PACKAGE\.ps1''\)\s*\r?\n\s*if\(\$LASTEXITCODE'){
  throw '[FAIL] DEV still reads possibly-unset LASTEXITCODE after direct .ps1 invocation'
}
Write-Host '[PASS] DEV uses isolated child PowerShell and initialized exit-code state under StrictMode' -ForegroundColor Green
Write-Host 'DEV StrictMode exit-code regression PASS' -ForegroundColor Cyan
