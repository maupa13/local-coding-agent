[CmdletBinding()]
param(
  [string]$ConfigPath,
  [string[]]$Candidates = @(
    'qwen3.5:9b-q4_K_M',
    'qwen2.5-coder-7b-32k:latest',
    'qwen2.5-coder:7b',
    'qwen3:8b',
    'brnpistone/Qwen3.5-4B-AgentCoder-q6-k:latest',
    'qwen2.5-coder:1.5b'
  )
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

function Get-InstalledModelNames {
  try {
    $tags=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5
    return @($tags.models | ForEach-Object { [string]$_.name })
  } catch {
    Fail 32 "Ollama is not reachable at http://127.0.0.1:11434. $($_.Exception.Message)"
  }
}

function Test-ModelInstalled([string]$Model,[string[]]$Installed){
  $wanted=$Model.ToLowerInvariant() -replace ':latest$',''
  foreach($item in $Installed){
    $actual=$item.ToLowerInvariant() -replace ':latest$',''
    if($actual -eq $wanted -or $actual.StartsWith($wanted+':')){return $true}
  }
  return $false
}

function Set-PrimaryModelInText([string]$Text,[string]$Model){
  $nameRegex=[regex]::new('(?m)^- name: Local Agent \([^\r\n]*\)$')
  $modelRegex=[regex]::new('(?m)^  model: [^\r\n]+$')
  $updated=$nameRegex.Replace($Text,"- name: Local Agent ($Model)",1)
  $updated=$modelRegex.Replace($updated,"  model: $Model",1)
  return $updated
}

$installed=Get-InstalledModelNames
$base=Get-Content -LiteralPath $ConfigPath -Raw
$powershellExe=(Get-Command powershell.exe -ErrorAction Stop).Source
$smoke=Join-Path $root 'tests\RUN-CONTINUE-TOOL-SMOKE.ps1'
$tmpRoot=Join-Path ([IO.Path]::GetTempPath()) ('lca-model-select-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

$ordered=New-Object System.Collections.Generic.List[string]
foreach($candidate in $Candidates){
  if(-not $ordered.Contains($candidate)){$ordered.Add($candidate)}
}

Write-Host '== Selecting Continue/Ollama tool model ==' -ForegroundColor Cyan
$selected=$null
try {
  foreach($candidate in $ordered){
    if(-not(Test-ModelInstalled $candidate $installed)){
      Write-Host "[SKIP] Not installed: $candidate" -ForegroundColor DarkGray
      continue
    }

    $candidateConfig=Join-Path $tmpRoot ((($candidate -replace '[^A-Za-z0-9._-]','_'))+'.yaml')
    $candidateText=Set-PrimaryModelInText $base $candidate
    Set-Content -LiteralPath $candidateConfig -Value $candidateText -Encoding UTF8

    Write-Host "[TEST] $candidate" -ForegroundColor Cyan
    & $powershellExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $smoke -ConfigPath $candidateConfig | Out-Host
    $code=[int]$LASTEXITCODE
    if($code -eq 0){
      $selected=$candidate
      Write-Host "[PASS] Working tool model: $candidate" -ForegroundColor Green
      break
    }
    Write-Host "[WARN] Continue tool execution failed with $candidate (exit $code); trying fallback." -ForegroundColor Yellow
  }

  if(-not $selected){
    Write-Host ''
    Write-Host '[FAIL] None of the installed candidate models completed a real Continue file edit.' -ForegroundColor Red
    Write-Host '[INFO] This points to a Continue CLI/Ollama tool-integration problem rather than project bootstrap.' -ForegroundColor Yellow
    Write-Host '[INFO] Candidates tested:' -ForegroundColor Yellow
    foreach($candidate in $ordered){if(Test-ModelInstalled $candidate $installed){Write-Host "  - $candidate"}}
    exit 34
  }

  foreach($relative in @('config\config-agent.yaml','config\config.yaml')){
    $path=Join-Path $root $relative
    if(Test-Path -LiteralPath $path){
      $text=Get-Content -LiteralPath $path -Raw
      $updated=Set-PrimaryModelInText $text $selected
      if($updated -ne $text){
        Set-Content -LiteralPath $path -Value $updated -Encoding UTF8
        Write-Host "[UPDATE] $relative -> $selected" -ForegroundColor Green
      }
    }
  }

  $selectionFile=Join-Path $root 'config\selected-tool-model.txt'
  Set-Content -LiteralPath $selectionFile -Value $selected -Encoding ASCII
  Write-Host "[PASS] Selected model persisted: $selectionFile" -ForegroundColor Green
  exit 0
}
finally {
  Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}
