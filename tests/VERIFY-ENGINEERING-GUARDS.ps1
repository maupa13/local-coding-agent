[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$config=Get-Content (Join-Path $root 'config\config-agent.yaml') -Raw

$needles=@(
 'function Get-DependencyGuardPolicyArgs',
 'function Get-DependencySensitiveState',
 'function Get-AgentPolicyViolations',
 'function Apply-AgentQualityGate',
 'function Test-CargoManifestIntegrity',
 'resumableWorkflow',
 'QUALITY GATE:',
 '--allow','Bash',
 'Bash(cargo update*)',
 'Bash(Set-Location*)',
 'Bash(*&&*)',
 'Edit(**/$name)',
 'Managed workflows do not support -Auto'
)
foreach($needle in $needles){
 if($module -notmatch [regex]::Escape($needle)){throw "Missing engineering guard: $needle"}
 Write-Host "[PASS] $needle"
}
$depsNeedle = "if (`$line -match '^/deps\s+(on|off)$')"
if(-not $module.Contains($depsNeedle)){throw 'Missing engineering guard: /deps on|off command parser'}
Write-Host '[PASS] /deps on|off command parser'
foreach($needle in @('COMMAND ANCHORING','DEPENDENCY FIREWALL','pass `--manifest-path','never run bare `cargo update`','/deps on')){
 if($config -notmatch [regex]::Escape($needle)){throw "Missing core rule: $needle"}
 Write-Host "[PASS] core rule $needle"
}
if($module -notmatch "dependency-sensitive file changed without opt-in") { throw 'Missing protected-file hard failure' }
if($module -notmatch "cargo metadata --no-deps --format-version 1 --locked --manifest-path") { throw 'Missing deterministic Cargo manifest validation' }
Write-Host 'Engineering guards PASS' -ForegroundColor Green
