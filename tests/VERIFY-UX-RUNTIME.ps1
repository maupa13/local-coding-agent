[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

function Need([string]$Pattern,[string]$Name){
  if($m -notmatch $Pattern){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

Need 'function Get-AgentLanguage' 'request-language detection'
Need 'USER-FACING LANGUAGE: Russian' 'Russian response directive'
Need '\$HeartbeatSeconds=10' 'runtime heartbeat cadence'
Need '\$StallWarningSeconds=60' 'stall warning threshold'
Need '\$MaxRuntimeSeconds=600' 'hard runtime timeout'
Need 'taskkill\.exe /PID \$process\.Id /T /F' 'cancel/timeout kills process tree'
Need 'Ctrl\+C' 'visible cancellation hint'
Need 'Get-Content -LiteralPath \$stdoutPath' 'live stdout-file polling'
Need 'Write-AgentProgressFromLine -Line \$liveLine' 'live activity rendering'
Need '\$cnArgs \+= ''--silent''' 'managed Continue headless output mode'
Need 'изменено агентом:' 'Russian per-run changed-file summary'
Need 'было изменено до запуска:' 'pre-existing changes separated'
if($m -match "Write-Host '  Developer report'"){throw '[FAIL] raw Developer report label still exposed by default'}
Write-Host '[PASS] raw Developer report label hidden from normal UX' -ForegroundColor Green
Write-Host 'Runtime UX regression PASS' -ForegroundColor Cyan
