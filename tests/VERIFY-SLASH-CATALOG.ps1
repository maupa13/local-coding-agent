[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$catalogPath = Join-Path $root 'workflows\catalog.json'
if (-not (Test-Path $catalogPath)) { throw "Missing catalog: $catalogPath" }
$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
if ($catalog.version -ne '1.0.0-dev') { throw "Unexpected catalog version: $($catalog.version)" }
if (@($catalog.workflows).Count -ne 22) { throw "Expected 22 workflows, got $(@($catalog.workflows).Count)" }
$configs = @('config.yaml','config-agent.yaml','config-agent-fast.yaml')
foreach ($item in $catalog.workflows) {
    $wfPath = Join-Path $root ('workflows\' + $item.file)
    if (-not (Test-Path $wfPath)) { throw "Missing workflow file: $wfPath" }
    $heading = (Get-Content $wfPath | Select-Object -First 1)
    foreach ($cfg in $configs) {
        $text = Get-Content (Join-Path $root ('config\' + $cfg)) -Raw
        if ($text -notmatch ('(?m)^- name: ' + [regex]::Escape([string]$item.name) + '$')) { throw "$cfg missing /$($item.name)" }
        if ($text -notmatch [regex]::Escape($heading)) { throw "$cfg does not contain full workflow content for /$($item.name)" }
    }
}
Write-Host "Slash catalog PASS: $($catalog.workflows.Count) workflows synchronized across 3 configs." -ForegroundColor Green
