[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$files=Get-ChildItem $root -Recurse -File | Where-Object { $_.Extension -in @('.ps1','.psm1') }
foreach($f in $files){
    $bytes=[IO.File]::ReadAllBytes($f.FullName)
    if($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF){
        throw "Windows PowerShell 5.1 UTF-8 BOM missing: $($f.FullName)"
    }
}
$m=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
if($m -match 'Get-RequirementSourceCandidates[\s\S]{0,1800}(?:ИСТОЧНИК|ДОКУМЕНТАЦИЯ|по\\s\+пути)'){
    throw 'Parser-sensitive requirement-source regex must remain ASCII-only.'
}
Write-Host '[PASS] Windows PowerShell 5.1 encoding/regex compatibility' -ForegroundColor Green
