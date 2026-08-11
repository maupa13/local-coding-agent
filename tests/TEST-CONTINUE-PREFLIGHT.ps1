[CmdletBinding()]
param(
  [string]$ConfigPath,
  [string]$Model = 'qwen3.5:9b-q4_K_M'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(-not $ConfigPath){$ConfigPath=Join-Path $root 'config\config-agent.yaml'}
if(-not(Test-Path -LiteralPath $ConfigPath)){throw "Config not found: $ConfigPath"}

function Fail([int]$Code,[string]$Message){
  Write-Host "[FAIL] $Message" -ForegroundColor Red
  exit $Code
}

$cn=Get-Command cn -ErrorAction SilentlyContinue
if(-not $cn){Fail 30 "Continue CLI 'cn' is not available in PATH. Install it with: npm install -g @continuedev/cli"}

try{
  $ver=& $cn.Source --version 2>&1
  if($LASTEXITCODE -ne 0){Fail 30 "Continue CLI exists but 'cn --version' failed."}
  Write-Host "[PASS] Continue CLI: $($ver -join ' ')" -ForegroundColor Green
}catch{Fail 30 "Continue CLI cannot be executed: $($_.Exception.Message)"}

try{
  & $cn.Source --help *> $null
  if($LASTEXITCODE -ne 0){Fail 30 "Continue CLI exists but 'cn --help' exits with code $LASTEXITCODE."}
  Write-Host '[PASS] Continue CLI help/argument parser' -ForegroundColor Green
}catch{Fail 30 "Continue CLI help check failed: $($_.Exception.Message)"}

try{$tags=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5}
catch{Fail 32 "Ollama is not reachable at http://127.0.0.1:11434. Start Ollama first. $($_.Exception.Message)"}
Write-Host '[PASS] Ollama HTTP API' -ForegroundColor Green

$names=@($tags.models|ForEach-Object{[string]$_.name})
$normalized=$Model.ToLowerInvariant() -replace ':latest$',''
$found=$false
foreach($n in $names){
  $a=$n.ToLowerInvariant() -replace ':latest$',''
  if($a -eq $normalized -or $a.StartsWith($normalized+':')){$found=$true;break}
}
if(-not $found){Fail 33 "Required model '$Model' is not installed in Ollama."}
Write-Host "[PASS] Ollama model: $Model" -ForegroundColor Green

$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-cn-preflight-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp|Out-Null
$stdout=Join-Path $tmp 'stdout.txt'
$stderr=Join-Path $tmp 'stderr.txt'
$cnArgs=@('--config',$ConfigPath,'--verbose','-p','Reply exactly LCA_PREFLIGHT_OK. Do not use tools.')

Push-Location $tmp
try{
  & $cn.Source @cnArgs 1> $stdout 2> $stderr
  $code=[int]$LASTEXITCODE
}finally{Pop-Location}

$out=if(Test-Path $stdout){Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue}else{''}
$err=if(Test-Path $stderr){Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue}else{''}
$combined=(($out+"`n"+$err).Trim())

if($code -ne 0){
  Write-Host "[FAIL] Continue headless preflight exited $code" -ForegroundColor Red
  if(-not [string]::IsNullOrWhiteSpace($combined)){
    Write-Host '--- Continue output ---' -ForegroundColor Yellow
    Write-Host $combined
  }else{
    Write-Host '[DIAG] Continue produced no stdout/stderr.' -ForegroundColor Yellow
    Write-Host '[DIAG] Current Continue CLI requires a first-run authentication step before headless use.' -ForegroundColor Yellow
    Write-Host '[ACTION] Run: cn login' -ForegroundColor Cyan
    Write-Host '[ACTION] Then rerun: .\tests\TEST-CONTINUE-PREFLIGHT.ps1' -ForegroundColor Cyan
    Write-Host '[NOTE] Inference remains configured for local Ollama, but Continue CLI authentication itself is not air-gapped.' -ForegroundColor DarkYellow
  }
  Write-Host "Diagnostics: $tmp" -ForegroundColor DarkGray
  exit 31
}

if($combined -notmatch 'LCA_PREFLIGHT_OK'){
  Write-Host '[WARN] Continue exited 0 but did not emit the expected marker.' -ForegroundColor Yellow
  Write-Host $combined
}else{
  Write-Host '[PASS] Continue headless request reached configured local model' -ForegroundColor Green
}
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
exit 0
