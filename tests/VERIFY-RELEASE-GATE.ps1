[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$required=@(
  'tests\NEW-RELEASE-E2E-REPO.ps1',
  'tests\RUN-LIVE-E2E.ps1',
  'tests\RUN-RELEASE-QUALIFICATION.ps1',
  'tests\RUN-STARTUP-SMOKE.ps1',
  'tests\RUN-SHELL-E2E.ps1',
  'powershell\QUALIFY-RELEASE.ps1',
  'docs\RELEASE-ACCEPTANCE.md'
)
foreach($rel in $required){if(-not(Test-Path -LiteralPath (Join-Path $root $rel))){throw "Missing release gate asset: $rel"}}
$runAll=Get-Content -LiteralPath (Join-Path $root 'tests\RUN-ALL.ps1') -Raw
foreach($needle in @('[switch]$LiveE2E','STARTUP-SMOKE','LIVE-E2E','SHELL-E2E','RUN-LIVE-E2E.ps1','RUN-SHELL-E2E.ps1','NOT RUN')){if($runAll -notmatch [regex]::Escape($needle)){throw "RUN-ALL release gate missing: $needle"}}
$activate=Get-Content -LiteralPath (Join-Path $root 'powershell\ACTIVATE.ps1') -Raw
foreach($needle in @('CandidateVersion','InstalledVersion','does not match candidate')){if($activate -notmatch [regex]::Escape($needle)){throw "Activation version guard missing: $needle"}}
$native=Get-Content -LiteralPath (Join-Path $root 'tests\VERIFY-NATIVE-STDERR.ps1') -Raw
if($native -notmatch 'Select-Object -First 1'){throw 'Native stderr test must bind exactly one module instance.'}
$install=Get-Content -LiteralPath (Join-Path $root 'powershell\INSTALL.ps1') -Raw
if($install -notmatch "Copy-Item .*'VERSION'.*AgentHome"){throw 'Installer must copy VERSION into installed runtime.'}
Write-Host '[PASS] Release qualification gate contract' -ForegroundColor Green
