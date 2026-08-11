[CmdletBinding()]
param([switch]$Clean,[switch]$SkipTests)
$ErrorActionPreference='Stop'
try {
    & (Join-Path $PSScriptRoot 'build\Build-Distribution.ps1') -Clean:$Clean -SkipTests:$SkipTests
    exit 0
} catch {
    Write-Error $_
    exit 1
}
