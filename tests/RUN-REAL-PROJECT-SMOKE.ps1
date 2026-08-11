[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Project)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(-not(Test-Path $Project -PathType Container)){throw "Project not found: $Project"}
$git=(Get-Command git.exe -ErrorAction SilentlyContinue)
if(-not $git){$git=(Get-Command git -ErrorAction Stop)}
$oldEap=$ErrorActionPreference;$ErrorActionPreference='Continue'
try{
  $top=& $git.Source -C $Project rev-parse --show-toplevel 2>$null
  $gitCode=$LASTEXITCODE
}finally{$ErrorActionPreference=$oldEap}
if($gitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($top|Out-String).Trim())){throw 'RealProject must be a Git repository'}
$runtimeHome=Join-Path $HOME '.continue\local-coding-agent'
$runtime=Join-Path $runtimeHome 'LocalCodingAgent.psm1'
$runtimeVersion=Join-Path $runtimeHome 'VERSION'
$expectedVersion=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if(-not(Test-Path $runtime)){throw 'Installed Local Coding Agent runtime not found. Install/activate the candidate build first.'}
if(-not(Test-Path $runtimeVersion)){throw 'Installed runtime VERSION marker missing. Reinstall the candidate build.'}
$installedVersion=(Get-Content $runtimeVersion -Raw).Trim()
if($installedVersion -ne $expectedVersion){throw "Installed runtime version $installedVersion does not match candidate $expectedVersion."}
Import-Module $runtime -Force -DisableNameChecking
if(-not(Get-Command agent-doctor -ErrorAction SilentlyContinue)){throw 'agent-doctor command missing after runtime import'}
$oldExpected=$env:LOCAL_CODING_AGENT_EXPECTED_VERSION
try{
  $env:LOCAL_CODING_AGENT_EXPECTED_VERSION=$expectedVersion
  agent-doctor -Deep
}finally{
  $env:LOCAL_CODING_AGENT_EXPECTED_VERSION=$oldExpected
}
Write-Host '[PASS] installed runtime doctor'
Write-Host '[PASS] real project Git root resolved'
Write-Host '[PASS] installed runtime version matches candidate'
Write-Host '[INFO] Mutating model qualification runs separately in isolated RUN-LIVE-E2E.ps1 fixture.'
