[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

function Need([string]$Pattern,[string]$Name){
  if($module -notmatch $Pattern){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

Need 'function Get-AgentTerminalFinalReport' 'terminal final report extractor'
Need 'Only the LAST line-start FINAL RESULT block' 'terminal report ignores earlier transcript/rule text'
Need '\$matches\[\$matches\.Count-1\]' 'semantic parser uses last FINAL RESULT'
Need '\$report=Get-AgentTerminalFinalReport -Text \$Text' 'semantic status scopes to terminal report'
Need '\$matrixMatch=\[regex\]::Match\(\$Text' 'compliance matrix may be immediately before terminal report'
Need '\$status=Get-FinalResultStatus \$report' 'terminal FINAL RESULT remains authoritative'
Need 'Get-AgentTerminalFinalReport -Text \$combined' 'persisted final result uses terminal report only'
Write-Host 'Terminal compliance validation regression PASS' -ForegroundColor Cyan
