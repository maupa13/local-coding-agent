[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manifestPath = Join-Path $root 'powershell\LocalCodingAgent.psd1'

# Test the public package boundary, not a direct .psm1 import. This catches a
# broken manifest and accidental exports that source-level tests would miss.
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
if ($manifest.PowerShellVersion -gt [version]'5.1') { throw 'module no longer supports Windows PowerShell 5.1' }

$module = Import-Module $manifestPath -Force -PassThru -DisableNameChecking
try {
    $exported = @($module.ExportedFunctions.Keys)
    foreach ($required in @('Start-LocalCodingAgent','Invoke-AgentWorkflow','Invoke-AgentArtifactAnalysis','agent-doctor')) {
        if ($required -notin $exported) { throw "required public command is not exported: $required" }
    }
    if ('Get-AgentPackageRoot' -in $exported) { throw 'private path helper leaked into public API' }

    $installer = Get-Content -LiteralPath (Join-Path $root 'powershell\INSTALL.ps1') -Raw
    $activation = Get-Content -LiteralPath (Join-Path $root 'powershell\ACTIVATE.ps1') -Raw
    if ($installer -notmatch "LocalCodingAgent\.psd1") { throw 'installer does not deploy/import the module manifest' }
    if ($activation -notmatch "LocalCodingAgent\.psd1") { throw 'activation bypasses the module manifest' }
} finally {
    Remove-Module $module.Name -Force -ErrorAction SilentlyContinue
}

Write-Host '[PASS] module manifest, public API, installer, and activation boundary' -ForegroundColor Green
