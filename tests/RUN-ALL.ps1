[CmdletBinding()]
param(
 [ValidateSet('Quick','Full','Release')][string]$Profile='Quick',
 [string]$RealProject,
 [string]$OutDir,
 [switch]$LiveE2E,
 [switch]$HarnessSelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(-not $OutDir){
 $testBase=Join-Path ([System.IO.Path]::GetTempPath()) 'LocalCodingAgent\test-results'
 $runName=(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
 $OutDir=Join-Path $testBase $runName
}
New-Item -ItemType Directory -Path $OutDir -Force|Out-Null
$results=New-Object System.Collections.Generic.List[object]
function Get-TestLogPath([string]$Tier,[string]$Name,[string]$Directory){
 $safeName = (($Tier + '-' + $Name) -replace '[^A-Za-z0-9_.-]','_')
 return (Join-Path $Directory ($safeName + '.log'))
}
if($HarnessSelfTest){
 $probe = Get-TestLogPath 'regression' 'HARNESS SELF TEST' $OutDir
 if([System.IO.Path]::GetFileName($probe) -ne 'regression-HARNESS_SELF_TEST.log'){throw "Unexpected harness log path: $probe"}
 Write-Host '[PASS] RUN-ALL harness self-test' -ForegroundColor Green
 exit 0
}
function Add-Result([string]$Tier,[string]$Name,[string]$Status,[int]$ExitCode,[string]$Evidence){
 $results.Add([pscustomobject]@{tier=$Tier;name=$Name;status=$Status;exitCode=$ExitCode;evidence=$Evidence})
 $color=if($Status -eq 'PASS'){'Green'}elseif($Status -eq 'NOT RUN'){'Yellow'}else{'Red'}
 Write-Host "[$Status] $Tier / $Name" -ForegroundColor $color
}
function Invoke-Test([string]$Tier,[string]$Name,[string]$Script,[string[]]$Arguments=@()){
 $path=Join-Path $root $Script
 $log = Get-TestLogPath $Tier $Name $OutDir
 try{
   $exe=(Get-Command powershell.exe -ErrorAction Stop).Source
   $argList=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$path)+$Arguments
   & $exe @argList *> $log
   $ec=$LASTEXITCODE
   if($ec -eq 0){Add-Result $Tier $Name 'PASS' 0 $log}else{Add-Result $Tier $Name 'FAIL' $ec $log}
 }catch{
   $_ | Out-String | Set-Content -Encoding UTF8 $log
   Add-Result $Tier $Name 'FAIL' 1 $log
 }
}
Write-Host "Local Coding Agent test harness · $Profile" -ForegroundColor Cyan
Invoke-Test 'package' 'VERIFY-PACKAGE' 'powershell\VERIFY-PACKAGE.ps1'
Invoke-Test 'regression' 'HISTORICAL-BUGS' 'tests\VERIFY-REGRESSION-HISTORY.ps1'
Invoke-Test 'regression' 'TEST-MATRIX' 'tests\VERIFY-TEST-MATRIX.ps1'
Invoke-Test 'regression' 'PS51-COMPAT' 'tests\VERIFY-PS51-COMPAT.ps1'
Invoke-Test 'regression' 'MODULE-BOUNDARY' 'tests\VERIFY-MODULE-BOUNDARY.ps1'
Invoke-Test 'regression' 'WORK-ITEM-WORKFLOW' 'tests\VERIFY-WORK-ITEM-WORKFLOW.ps1'
Invoke-Test 'regression' 'ARTIFACT-ANALYSIS' 'tests\VERIFY-ARTIFACT-ANALYSIS.ps1'
Invoke-Test 'regression' 'NATIVE-STDERR' 'tests\VERIFY-NATIVE-STDERR.ps1'
Invoke-Test 'regression' 'NATIVE-OLLAMA-LOOP' 'tests\VERIFY-NATIVE-OLLAMA-LOOP.ps1'
Invoke-Test 'regression' 'RELEASE-GATE' 'tests\VERIFY-RELEASE-GATE.ps1'
Invoke-Test 'regression' 'FIXTURE-GENERATORS' 'tests\VERIFY-FIXTURE-GENERATORS.ps1'
Invoke-Test 'regression' 'OUTPUT-ISOLATION' 'tests\VERIFY-OUTPUT-ISOLATION.ps1'
Invoke-Test 'regression' 'WRAPPER-FINALIZER' 'tests\VERIFY-WRAPPER-FINALIZER.ps1'
Invoke-Test 'regression' 'TERMINAL-COMPLIANCE' 'tests\VERIFY-TERMINAL-COMPLIANCE-REPORT.ps1'
Invoke-Test 'regression' 'COMPLIANCE-REQ-EXTRACTION' 'tests\VERIFY-COMPLIANCE-REQUIREMENT-EXTRACTION.ps1'
Invoke-Test 'regression' 'COMPLIANCE-FINALIZER-NONZERO' 'tests\VERIFY-COMPLIANCE-FINALIZER-NONZERO.ps1'
Invoke-Test 'regression' 'COMPLIANCE-RUNTIME-SELFTEST' 'tests\VERIFY-COMPLIANCE-RUNTIME-SELFTEST.ps1'
Invoke-Test 'regression' 'DIAGNOSTIC-LOGGING' 'tests\VERIFY-DIAGNOSTIC-LOGGING.ps1'
Invoke-Test 'regression' 'LOG-ISOLATION' 'tests\VERIFY-LOG-ISOLATION.ps1'
Invoke-Test 'regression' 'COMPLIANCE-MATRIX-LAYOUT' 'tests\VERIFY-COMPLIANCE-MATRIX-LAYOUT.ps1'
Invoke-Test 'regression' 'QUALIFY-ARGUMENT-BINDING' 'tests\VERIFY-QUALIFY-ARGUMENT-BINDING.ps1'
Invoke-Test 'regression' 'EXTRACTOR-STAGED-DIAGNOSTICS' 'tests\VERIFY-EXTRACTOR-STAGED-DIAGNOSTICS.ps1'
Invoke-Test 'regression' 'PS-VARIABLE-COLON-HYGIENE' 'tests\VERIFY-PS-VARIABLE-COLON-HYGIENE.ps1'
Invoke-Test 'regression' 'DEV-WORKSPACE' 'tests\VERIFY-DEV-WORKSPACE.ps1'
Invoke-Test 'regression' 'MODEL-TOOL-GATE' 'tests\VERIFY-MODEL-TOOL-GATE.ps1'
Invoke-Test 'regression' 'PS51-PATH-CHARS' 'tests\VERIFY-PS51-PATH-CHARS.ps1'
Invoke-Test 'regression' 'FILESYSTEM-FIRST-INVENTORY' 'tests\VERIFY-FILESYSTEM-FIRST-INVENTORY.ps1'
Invoke-Test 'regression' 'NON-GIT-INVENTORY' 'tests\VERIFY-NON-GIT-INVENTORY.ps1'
Invoke-Test 'regression' 'DOC-EDIT-ROUTING' 'tests\VERIFY-DOC-EDIT-ROUTING.ps1'
Invoke-Test 'acceptance' 'DOC-EDIT-USER-JOURNEY' 'tests\VERIFY-DOC-EDIT-USER-JOURNEY.ps1'
Invoke-Test 'regression' 'PROJECT-ROOT-SELECTION' 'tests\VERIFY-PROJECT-ROOT-SELECTION.ps1'
Invoke-Test 'regression' 'DEV-STRICTMODE-EXITCODE' 'tests\VERIFY-DEV-STRICTMODE-EXITCODE.ps1'
Invoke-Test 'regression' 'UX-RUNTIME' 'tests\VERIFY-UX-RUNTIME.ps1'
Invoke-Test 'regression' 'RUN-CHANGE-ACCOUNTING' 'tests\VERIFY-RUN-CHANGE-ACCOUNTING.ps1'
Invoke-Test 'regression' 'STRICTMODE-HYGIENE' 'tests\VERIFY-STRICTMODE-TEST-HYGIENE.ps1'
Invoke-Test 'regression' 'COMPLIANCE-FINALIZER' 'tests\VERIFY-COMPLIANCE-FINALIZER-CONTRACT.ps1'
Invoke-Test 'regression' 'SANDBOX-VERSION' 'tests\VERIFY-SANDBOX-VERSION.ps1'
Invoke-Test 'regression' 'UTF8-CAPTURE' 'tests\VERIFY-UTF8-CAPTURE.ps1'
Invoke-Test 'regression' 'PROJECT-BOOTSTRAP' 'tests\VERIFY-PROJECT-BOOTSTRAP.ps1'
Invoke-Test 'regression' 'AGENTIC-PIPELINE' 'tests\VERIFY-AGENTIC-PIPELINE.ps1'
if($Profile -in @('Full','Release')){
 $fixtureRoot=Join-Path $OutDir 'fixtures'
 New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
 Invoke-Test 'acceptance' 'GENERIC-FIXTURE' 'tests\NEW-ACCEPTANCE-REPO.ps1' @('-Destination',(Join-Path $fixtureRoot 'generic'))
 Invoke-Test 'acceptance' 'RUST-GUARD-FIXTURE' 'tests\NEW-RUST-GUARD-REPO.ps1' @('-OutDir',(Join-Path $fixtureRoot 'rust-guard'))
 Invoke-Test 'acceptance' 'DOC-SOURCE-FIXTURE' 'tests\NEW-DOC-SOURCE-REPO.ps1' @('-Project',(Join-Path $fixtureRoot 'doc-source'),'-Docs',(Join-Path $fixtureRoot 'doc-source-docs'),'-Force')
 Invoke-Test 'acceptance' 'COMPLIANCE-FIXTURE' 'tests\NEW-COMPLIANCE-REPO.ps1' @('-Path',(Join-Path $fixtureRoot 'compliance'))
 Invoke-Test 'lifecycle' 'INSTALL-FAIL-CLOSED' 'tests\VERIFY-INSTALL-FAIL-CLOSED.ps1'
 Invoke-Test 'lifecycle' 'IDEA-INTEGRATION' 'tests\VERIFY-IDEA-INTEGRATION.ps1'
 Invoke-Test 'lifecycle' 'MULTIPROJECT-UX' 'tests\VERIFY-MULTIPROJECT-UX.ps1'
}
if($Profile -eq 'Release'){
 if([string]::IsNullOrWhiteSpace($RealProject)){
   Add-Result 'runtime' 'REAL-PROJECT-E2E' 'NOT RUN' 0 'Pass -RealProject <git repository> to qualify a release.'
 } elseif(-not(Test-Path $RealProject -PathType Container)){
   Add-Result 'runtime' 'REAL-PROJECT-E2E' 'FAIL' 2 "Project does not exist: $RealProject"
 } else {
   Invoke-Test 'runtime' 'STARTUP-SMOKE' 'tests\RUN-STARTUP-SMOKE.ps1' @('-Project',$RealProject)
   Invoke-Test 'runtime' 'REAL-PROJECT-SMOKE' 'tests\RUN-REAL-PROJECT-SMOKE.ps1' @('-Project',$RealProject)
   if($LiveE2E){
     Invoke-Test 'runtime' 'LIVE-E2E' 'tests\RUN-LIVE-E2E.ps1'
     Invoke-Test 'runtime' 'SHELL-E2E' 'tests\RUN-SHELL-E2E.ps1'
   } else {
     Add-Result 'runtime' 'LIVE-E2E' 'NOT RUN' 0 'Pass -LiveE2E for real model compliance -> bugfix -> test -> review qualification.'
     Add-Result 'runtime' 'SHELL-E2E' 'NOT RUN' 0 'Pass -LiveE2E for natural-language shell routing and /result qualification.'
   }
 }
}
$fail=@($results|Where-Object status -eq 'FAIL').Count
$notRun=@($results|Where-Object status -eq 'NOT RUN').Count
$verdict=if($fail -gt 0){'NO-GO'}elseif($Profile -eq 'Release' -and $notRun -gt 0){'NOT-QUALIFIED'}else{'GO'}
$payload=[pscustomobject]@{version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim();profile=$Profile;generatedAt=(Get-Date).ToString('o');verdict=$verdict;passed=@($results|Where-Object status -eq 'PASS').Count;failed=$fail;notRun=$notRun;results=$results}
$payload|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 (Join-Path $OutDir 'results.json')
$lines=New-Object System.Collections.Generic.List[string]
$lines.Add("# Local Coding Agent Test Report")
$lines.Add('')
$lines.Add("- Version: $($payload.version)")
$lines.Add("- Profile: $Profile")
$lines.Add("- Verdict: **$verdict**")
$lines.Add("- PASS: $($payload.passed) · FAIL: $fail · NOT RUN: $notRun")
$lines.Add('')
$lines.Add('| Tier | Test | Status | Evidence |')
$lines.Add('|---|---|---|---|')
foreach($r in $results){$lines.Add("| $($r.tier) | $($r.name) | $($r.status) | $($r.evidence) |")}
$lines|Set-Content -Encoding UTF8 (Join-Path $OutDir 'report.md')
Write-Host "`nRELEASE VERDICT: $verdict" -ForegroundColor $(if($verdict -eq 'GO'){'Green'}elseif($verdict -eq 'NOT-QUALIFIED'){'Yellow'}else{'Red'})
Write-Host "Report: $(Join-Path $OutDir 'report.md')"
if($fail -gt 0){
  Write-Host 'Failed test logs:' -ForegroundColor Yellow
  foreach($r in @($results|Where-Object status -eq 'FAIL')){Write-Host ("  - {0}/{1}: {2}" -f $r.tier,$r.name,$r.evidence) -ForegroundColor Yellow}
}
if($verdict -eq 'NO-GO'){exit 1}
if($verdict -eq 'NOT-QUALIFIED'){exit 2}
