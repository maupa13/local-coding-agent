[CmdletBinding()]
param([string]$Project)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$expected=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$runtimeHome=Join-Path $HOME '.continue\local-coding-agent'
$runtimeVersion=Join-Path $runtimeHome 'VERSION'
$launcher=Join-Path $runtimeHome 'IDEA-LAUNCH.ps1'
if(-not(Test-Path -LiteralPath $runtimeVersion)){throw 'Installed runtime VERSION marker missing.'}
$installed=(Get-Content -LiteralPath $runtimeVersion -Raw).Trim()
if($installed -ne $expected){throw "Installed runtime version $installed does not match candidate $expected."}
if(-not(Test-Path -LiteralPath $launcher)){throw "Installed IDEA launcher missing: $launcher"}
$ownedProject=$false
if([string]::IsNullOrWhiteSpace($Project)){
  $Project=Join-Path ([System.IO.Path]::GetTempPath()) ('LocalCodingAgent-startup-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $Project|Out-Null
  '{"name":"lca-startup-smoke","private":true}'|Set-Content -Encoding UTF8 (Join-Path $Project 'package.json')
  $ownedProject=$true
}
if(-not(Test-Path -LiteralPath $Project -PathType Container)){throw "Startup smoke project missing: $Project"}
$exe=(Get-Command powershell.exe -ErrorAction Stop).Source
$psi=New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName=$exe
$psi.Arguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$launcher+'" -Project "'+$Project+'"'
$psi.WorkingDirectory=$Project
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$psi.RedirectStandardInput=$true
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
$p=New-Object System.Diagnostics.Process
$p.StartInfo=$psi
try{
  if(-not $p.Start()){throw 'Failed to start installed CLI.'}
  $stdoutTask=$p.StandardOutput.ReadToEndAsync()
  $stderrTask=$p.StandardError.ReadToEndAsync()
  foreach($line in @('/','/permissions','что ты можешь?','/project','/exit')){$p.StandardInput.WriteLine($line)}
  $p.StandardInput.Close()
  if(-not $p.WaitForExit(30000)){try{$p.Kill()}catch{};throw 'Installed CLI did not exit after /exit within 30 seconds.'}
  $stdout=$stdoutTask.Result
  $stderr=$stderrTask.Result
  if($p.ExitCode -ne 0){throw "Installed CLI exited $($p.ExitCode). stderr: $stderr stdout: $stdout"}
  foreach($needle in @('QG','Session','Permissions','current:','project:')){if($stdout -notmatch [regex]::Escape($needle)){throw "Startup smoke output missing '$needle'. Output: $stdout"}}
  if($stdout -match '(?im)^\s*\[FAIL\]'){throw "Startup smoke printed FAIL. Output: $stdout"}
  Write-Host '[PASS] installed CLI starts, accepts local commands, prints help/permissions/project, and exits cleanly' -ForegroundColor Green
}finally{
  if($p){$p.Dispose()}
  if($ownedProject){Remove-Item -LiteralPath $Project -Recurse -Force -ErrorAction SilentlyContinue}
}
