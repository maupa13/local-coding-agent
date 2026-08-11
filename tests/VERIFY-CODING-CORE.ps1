[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
function Need([string]$Name,[string]$Pattern){if($module -notmatch $Pattern){throw "Missing Coding Core contract: $Name"};Write-Host "[PASS] $Name" -ForegroundColor Green}
Need 'project permission default' "AgentPermissionMode = 'project'"
Need 'project policy function' 'function Get-ProjectPolicyArgs'
Need 'legacy safe migration' 'permissionSchemaVersion'
Need 'project dependency opt-in' 'effectiveAllowDependencies'
Need 'project permission parser' "\^/permissions.*project\|trusted"
Need 'direct delete guard' 'Bash\(Remove-Item\*\)'
Need 'destructive Git guard' 'Bash\(git reset --hard\*\)'
Need 'coding modes' 'function Get-AgentCodingMode'
Need '/mode command' "\^/mode"
Need 'effort profiles' 'function Get-AgentEffort'
Need '/effort command' "\^/effort"
Need 'token budget profiles' 'function Get-AgentBudgetValues'
Need 'runtime context patch' 'contextLength:'
Need 'runtime max token patch' 'maxTokens:'
Need '/budget command' "\^/budget"
Need 'project memory' 'function Get-AgentProjectMemory'
Need '/memory command' "\^/memory"
Need 'provider foundation' 'function Set-AgentProviderCommand'
Need '/provider command' "\^/provider"
Need 'session directive' 'function Get-AgentSessionDirective'
Need 'mode-aware routing' 'Resolve-AgentModeIntent'
Write-Host 'Coding Agent Core verification PASS' -ForegroundColor Cyan
