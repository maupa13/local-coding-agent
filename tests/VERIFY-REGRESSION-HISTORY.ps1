[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$install=Get-Content (Join-Path $root 'powershell\INSTALL.ps1') -Raw
$idea=Get-Content (Join-Path $root 'powershell\IDEA-INTEGRATE.ps1') -Raw
$quality=Get-Content (Join-Path $root 'tests\VERIFY-QUALITY-ENGINE.ps1') -Raw
$harness=Get-Content (Join-Path $root 'tests\RUN-ALL.ps1') -Raw
function Need([string]$Id,[string]$Name,[bool]$Condition){if(-not $Condition){throw "$Id $Name"};Write-Host "[PASS] $Id $Name" -ForegroundColor Green}
Need 'REG-001' 'PS5.1 compatibility suite retained' (Test-Path (Join-Path $root 'tests\VERIFY-PS51-COMPAT.ps1'))
Need 'REG-002' 'strict-mode quality contract retained' ($quality -match 'Set-StrictMode')
Need 'REG-003' 'launcher owns agent command' ($module -match 'Start-LocalCodingAgent')
Need 'REG-004' 'IDEA integration resolves interpreter' ($module.Contains('System32\WindowsPowerShell') -and $module.Contains('Get-Command powershell.exe'))
Need 'REG-005' '/model install parser retained' ($module -match 'Install-AgentOllamaModel')
Need 'REG-006' '/deps parser retained' ($module.Contains('^/deps'))
Need 'REG-007' 'natural result alias retained' ($module.Contains('ну\s+и') -or $module.Contains('что\s+(?:по\s+)?итогу'))
Need 'REG-008' 'robust Git detection retained' ($module -match 'rev-parse --show-toplevel')
Need 'REG-009' 'compliance completion validator retained' (($module -match 'Test-AgentComplianceResult') -and ($module -match 'Invoke-AgentComplianceRecovery'))
Need 'REG-010' 'compact/headless UI retained' (($module -match 'NO_COLOR') -and ($module -match 'TERM'))
Need 'REG-011' 'installer is fail-closed' (($install -match 'VERIFY-PACKAGE.ps1') -and ($install -match 'Nothing was installed|Full package verification failed'))
Need 'REG-012' 'model pull progress retained' (($install -match 'Invoke-OllamaPullProgress') -or ($module -match 'Invoke-OllamaPullProgress'))
Need 'REG-013' 'RUN-ALL harness log-path execution retained' (($harness -match 'Get-TestLogPath') -and ($harness -match 'HarnessSelfTest'))
Need 'REG-014' 'native stderr warnings cannot abort managed workflow' (($module -match 'Test-AgentNonFatalNativeWarning') -and ($module -match 'stderr\.txt') -and ($module -match 'native-warnings\.txt') -and (Test-Path (Join-Path $root 'tests\VERIFY-NATIVE-STDERR.ps1')))
Need 'REG-015' 'release qualification requires live E2E' (($harness -match 'LiveE2E') -and (Test-Path (Join-Path $root 'tests\VERIFY-RELEASE-GATE.ps1')) -and (Test-Path (Join-Path $root 'tests\RUN-LIVE-E2E.ps1')))
Need 'REG-017' 'fixture generators are isolated and repeatable' (Test-Path (Join-Path $root 'tests\VERIFY-FIXTURE-GENERATORS.ps1'))
Need 'REG-018' 'test output stays outside package/project roots' (($harness -match 'GetTempPath') -and (Test-Path (Join-Path $root 'tests\VERIFY-OUTPUT-ISOLATION.ps1')))
Need 'REG-019' 'package gate does not execute runtime probes' ((Get-Content (Join-Path $root 'powershell\VERIFY-PACKAGE.ps1') -Raw) -notmatch "Check 'Native stderr warning isolation'")

Need 'REG-020' 'empty managed output recovery regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-020')
Need 'REG-020A' 'empty compliance recovery parameter retained' ($module -match 'AllowEmptyString')
Need 'REG-020B' 'process success is not semantic success' ($module -match 'semantic result NOT CAPTURED')

Need 'REG-021' 'test matrix schema regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-021')
Need 'REG-022' 'wrapper finalizer regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-022')
Need 'REG-023' 'UTF-8 capture regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-023')
Need 'REG-024' 'compliance finalizer beta-contract regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-024')
Need 'REG-025' 'sandbox VERSION source-of-truth regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-025')
Need 'REG-026' 'terminal compliance validation regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-026')
Need 'REG-027' 'compliance requirement extraction regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-027')
Need 'REG-028' 'StrictMode verifier hygiene regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-028')
Need 'REG-029' 'compliance finalizer nonzero-exit regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-029')
Need 'REG-030' 'runtime compliance extractor self-test registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-030')
Need 'REG-031' 'diagnostic logging regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-031')
Need 'REG-032' 'qualification log isolation regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-032')
Need 'REG-033' 'compliance matrix layout regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-033')
Need 'REG-034' 'qualification argument binding regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-034')
Need 'REG-035' 'extractor staged diagnostics regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-035')
Need 'REG-036' 'PowerShell variable-colon hygiene regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-036')
Need 'REG-037' 'stable development workspace regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-037')
Need 'REG-038' 'runtime UX regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-038')
Need 'REG-039' 'result UX/change accounting regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-039')
Need 'REG-040' 'DEV StrictMode exit-code regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-040')
Need 'REG-041' 'project-root selection regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-041')
Need 'REG-042' 'document edit routing regression registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'REG-042')
Need 'ACC-006' 'document edit user journey registered' ((Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw) -match 'ACC-006')
Write-Host 'Historical regression contracts PASS' -ForegroundColor Cyan
