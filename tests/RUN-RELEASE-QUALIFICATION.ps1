[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RealProject,
  [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(-not(Test-Path -LiteralPath $RealProject -PathType Container)){throw "RealProject does not exist: $RealProject"}
$runAll=Join-Path $root 'tests\RUN-ALL.ps1'
$args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$runAll,'-Profile','Release','-RealProject',$RealProject,'-LiveE2E')
if($OutDir){$args += @('-OutDir',$OutDir)}
$exe=(Get-Command powershell.exe -ErrorAction Stop).Source
$oldEap=$ErrorActionPreference;$ErrorActionPreference='Continue'
try{
  & $exe @args
  $code=$LASTEXITCODE
}finally{$ErrorActionPreference=$oldEap}
if($code -ne 0){throw "Release qualification failed with exit code $code."}
Write-Host '[PASS] 1.0.0 release qualification complete' -ForegroundColor Green
