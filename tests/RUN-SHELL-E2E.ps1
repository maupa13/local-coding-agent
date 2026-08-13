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
if(-not $FixturePath){$FixturePath=Join-Path ([System.IO.Path]::GetTempPath()) ('LocalCodingAgent-shell-e2e-'+[guid]::NewGuid().ToString('N'))}
& (Join-Path $root 'tests\NEW-COMPLIANCE-REPO.ps1') -Path $FixturePath | Out-Null
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
$started=Get-Date
try{
  if(-not $p.Start()){throw 'Failed to start shell E2E.'}
  $stdoutTask=$p.StandardOutput.ReadToEndAsync();$stderrTask=$p.StandardError.ReadToEndAsync()
  $p.StandardInput.WriteLine('Проанализируй папку docs и проект на соответствие документации')
  $p.StandardInput.WriteLine('/result')
  $p.StandardInput.WriteLine('что ты можешь?')
  $p.StandardInput.WriteLine('/exit')
  $p.StandardInput.Close()
  if(-not $p.WaitForExit(420000)){try{$p.Kill()}catch{};throw 'Shell E2E timed out after 7 minutes.'}
  $stdout=$stdoutTask.Result;$stderr=$stderrTask.Result
  $combined=$stdout+"`n"+$stderr
  if($p.ExitCode -ne 0){throw "Shell E2E exited $($p.ExitCode). Output: $combined"}
  foreach($needle in @('routed','/analysis','Session')){if($combined -notmatch [regex]::Escape($needle)){throw "Shell E2E missing '$needle'. Output: $combined"}}
  $evidenceSession=Get-ChildItem -LiteralPath (Join-Path $runtimeHome 'evidence') -Filter session.json -File -Recurse -ErrorAction SilentlyContinue|ForEach-Object{
    try{$session=Get-Content -LiteralPath $_.FullName -Raw|ConvertFrom-Json;if([string]$session.repositoryRoot -eq $FixturePath -and [DateTime]::Parse([string]$session.startedAt) -ge $started){[pscustomobject]@{Session=$session;Directory=$_.DirectoryName}}}catch{}
  }|Sort-Object {[DateTime]::Parse([string]$_.Session.startedAt)} -Descending|Select-Object -First 1
  if(-not $evidenceSession){throw 'Shell E2E did not persist analysis evidence.'}
  $finalPath=Join-Path $evidenceSession.Directory 'final-result.txt'
  $finalEvidence=if(Test-Path -LiteralPath $finalPath){Get-Content -LiteralPath $finalPath -Raw}else{''}
  if(([string]$evidenceSession.Session.semanticStatus).ToUpperInvariant() -ne 'PASS' -or $finalEvidence -notmatch '(?i)FINAL RESULT:\s*PASS'){throw "Shell E2E evidence is not a completed final result: $finalPath"}
  foreach($id in 1..4){if($finalEvidence -notmatch ('REQ-{0:D2}' -f $id)){throw "Shell E2E evidence omitted REQ-$('{0:D2}' -f $id)."}}
  if($combined -match '(?im)^\s*\[FAIL\]\s+warning:\s+in the working copy'){throw 'Git LF/CRLF warning aborted or surfaced as fatal shell failure.'}
  if($combined -match 'getInputStream\(\) must not be called against a directory'){throw 'Directory-as-file regression returned in shell E2E.'}
  Write-Host '[PASS] real shell: natural language routing -> compliance result -> /result -> local capabilities' -ForegroundColor Green
}finally{
  if($p){$p.Dispose()}
  if(-not $KeepFixture){Remove-Item -LiteralPath $FixturePath -Recurse -Force -ErrorAction SilentlyContinue}
}
