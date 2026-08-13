[CmdletBinding()]
param([string]$FixturePath,[switch]$KeepFixture)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$expected=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$runtimeHome=Join-Path $HOME '.continue\local-coding-agent'
$runtimeVersion=Join-Path $runtimeHome 'VERSION'
$launcher=Join-Path $runtimeHome 'IDEA-LAUNCH.ps1'
if(-not(Test-Path -LiteralPath $runtimeVersion)){throw 'Installed runtime missing.'}
$installed=(Get-Content -LiteralPath $runtimeVersion -Raw).Trim()
if($installed -ne $expected){throw "Installed runtime version $installed does not match candidate $expected."}
if(-not $FixturePath){$FixturePath=Join-Path ([System.IO.Path]::GetTempPath()) ('LocalCodingAgent-result-e2e-'+[guid]::NewGuid().ToString('N'))}
& (Join-Path $root 'tests\NEW-COMPLIANCE-REPO.ps1') -Path $FixturePath | Out-Null
Import-Module (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Force

$analysisStarted=Get-Date
Invoke-AgentWorkflow -Workflow 'analyze' -DisplayWorkflow 'analysis' -Task 'Analyze the docs folder and project for documentation compliance.' -ReadOnly -Headless -Managed -ProjectRoot $FixturePath | Out-Null
$analysisEvidence=Get-ChildItem -LiteralPath (Join-Path $runtimeHome 'evidence') -Filter 'session.json' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    $session=Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    if(([string]$session.repositoryRoot) -ne $FixturePath){return}
    $started=[DateTime]::Parse([string]$session.startedAt)
    if($started -lt $analysisStarted){return}
    [pscustomobject]@{Session=$session;Directory=$_.DirectoryName;StartedAt=$started}
  } catch {}
} | Sort-Object StartedAt -Descending | Select-Object -First 1
if(-not $analysisEvidence){throw 'Analysis did not persist evidence.'}
$analysisFinal=Join-Path $analysisEvidence.Directory 'final-result.txt'
if(-not(Test-Path -LiteralPath $analysisFinal)){throw 'Analysis did not write final-result.txt.'}
$analysisText=Get-Content -LiteralPath $analysisFinal -Raw
if($analysisText -notmatch '(?i)FINAL RESULT:\s*PASS'){throw 'Initial analysis did not produce a pass final result.'}
foreach($id in 1..4){if($analysisText -notmatch ('REQ-{0:D2}' -f $id)){throw "Initial analysis omitted REQ-$('{0:D2}' -f $id)."}}

$exe=(Get-Command powershell.exe -ErrorAction Stop).Source
$psi=New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName=$exe
$psi.Arguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$launcher+'" -Project "'+$FixturePath+'"'
$psi.WorkingDirectory=$FixturePath
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$psi.RedirectStandardInput=$true
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
$p=New-Object System.Diagnostics.Process
$p.StartInfo=$psi
try{
  if(-not $p.Start()){throw 'Failed to start shell session.'}
  $stdoutTask=$p.StandardOutput.ReadToEndAsync()
  $stderrTask=$p.StandardError.ReadToEndAsync()
  $p.StandardInput.WriteLine('/result')
  Start-Sleep -Milliseconds 15000
  $p.StandardInput.WriteLine('/exit')
  $p.StandardInput.Close()
  if(-not $p.WaitForExit(420000)){try{$p.Kill()}catch{};throw 'Shell session timed out after 7 minutes.'}
  $stdout=$stdoutTask.Result
  $stderr=$stderrTask.Result
  if($p.ExitCode -ne 0){throw "Shell session exited $($p.ExitCode). Output: $($stdout + "`n" + $stderr)"}
  $combined=$stdout + "`n" + $stderr
  if($combined -notmatch '(?i)COMPLIANCE MATRIX' -and $combined -notmatch '(?i)FINAL RESULT'){throw "Recovered /result did not print a final result. Output: $combined"}
  foreach($id in 1..4){if($combined -notmatch ('REQ-{0:D2}' -f $id)){throw "Recovered /result omitted REQ-$('{0:D2}' -f $id)."}}
  Write-Host '[PASS] real shell: previous analysis session -> /result recovery -> persistent final result' -ForegroundColor Green
}finally{
  if($p){$p.Dispose()}
  if(-not $KeepFixture){Remove-Item -LiteralPath $FixturePath -Recurse -Force -ErrorAction SilentlyContinue}
}
