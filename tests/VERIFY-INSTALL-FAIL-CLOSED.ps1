[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$i=Get-Content (Join-Path $root 'powershell\INSTALL.ps1') -Raw
$need=@(
 'Running full package verification',
 'VERIFY-PACKAGE.ps1',
 'Full package verification failed',
 'Nothing was installed',
 'Invoke-OllamaPullProgress',
 'ResponseHeadersRead'
)
foreach($n in $need){if(-not $i.Contains($n)){throw "Missing fail-closed installer behavior: $n"};Write-Host "[PASS] $n"}
$verifyPos=$i.IndexOf("VERIFY-PACKAGE.ps1")
$ollamaPos=$i.IndexOf("/api/tags")
if($verifyPos -lt 0 -or $ollamaPos -lt 0 -or $verifyPos -gt $ollamaPos){throw 'Full package verification must happen before Ollama/model activity'}
Write-Host 'Installer fail-closed verification PASS' -ForegroundColor Green
