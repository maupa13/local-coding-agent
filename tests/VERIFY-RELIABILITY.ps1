[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$catalog=Get-Content (Join-Path $root 'workflows\catalog.json') -Raw|ConvertFrom-Json
foreach($item in $catalog.workflows){
 $text=Get-Content (Join-Path $root ('workflows\'+$item.file)) -Raw
 if($text -notmatch ('ACTIVE WORKFLOW: /'+[regex]::Escape([string]$item.name))){throw "/$($item.name) missing workflow lock"}
}
foreach($cfg in @('config.yaml','config-agent.yaml','config-agent-fast.yaml')){
 $text=Get-Content (Join-Path $root ('config\'+$cfg)) -Raw
 if(([regex]::Matches($text,'MANDATORY FINAL RESULT')).Count -ne 1){throw "$cfg must contain one global final-result contract"}
}
$module=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
foreach($needle in @('function Start-AgentShell','function Invoke-AgentRecovery','function Write-DeterministicFallbackResult','SEMANTIC RESULT:','function Test-IsAgentDistributionPath')){
 if($module -notmatch [regex]::Escape($needle)){throw "missing reliability feature: $needle"}
}
Write-Host 'Reliability PASS: managed shell, workflow lock, semantic final parser/recovery/fallback present.' -ForegroundColor Green
