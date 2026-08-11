[CmdletBinding()]
param(
  [Parameter(Position=0)][ValidateSet('status','checkpoint','test','install','qualify','restore')][string]$Action='status',
  [Parameter(Position=1)][string]$Message='development checkpoint',
  [string]$RealProject
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root


$script:DevLastExitCode=0

function Invoke-DevScript {
  param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [string[]]$Arguments=@()
  )
  $powershellExe=(Get-Command powershell.exe -ErrorAction Stop).Source
  & $powershellExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments | Out-Host
  $script:DevLastExitCode=[int]$LASTEXITCODE
  return $script:DevLastExitCode
}


function Need-Git {
  if(-not(Get-Command git -ErrorAction SilentlyContinue)){throw 'Git is required for development checkpoints.'}
  if(-not(Test-Path -LiteralPath (Join-Path $root '.git'))){
    git init | Out-Host
    git config user.name *> $null
    if($LASTEXITCODE -ne 0){git config user.name 'Local Coding Agent Dev'}
    git config user.email *> $null
    if($LASTEXITCODE -ne 0){git config user.email 'local-coding-agent@localhost'}
  }
}

switch($Action){
  'status' {
    Write-Host "Local Coding Agent development workspace" -ForegroundColor Cyan
    Write-Host "Path: $root"
    Write-Host "Version: $((Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim())"
    if(Test-Path -LiteralPath (Join-Path $root '.git')){
      git status --short
      git log -5 --oneline --decorate
    }else{
      Write-Host 'Git: not initialized yet; first checkpoint will initialize it.' -ForegroundColor Yellow
    }
  }
  'checkpoint' {
    Need-Git
    git add -A
    $changes=git status --porcelain
    if([string]::IsNullOrWhiteSpace(($changes|Out-String))){
      Write-Host '[INFO] Nothing changed; checkpoint not created.' -ForegroundColor Yellow
      break
    }
    git commit -m $Message
    if($LASTEXITCODE -ne 0){throw 'Git checkpoint commit failed.'}
    Write-Host '[PASS] Development checkpoint created.' -ForegroundColor Green
  }
  'test' {
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'VERIFY-PACKAGE.ps1')
    if($code -ne 0){exit $code}
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'tests\RUN-ALL.ps1') -Arguments @('-Profile','Full')
    exit $code
  }
  'install' {
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'VERIFY-PACKAGE.ps1')
    if($code -ne 0){exit $code}
    Write-Host '[preflight] Continue CLI + Ollama + headless readiness...' -ForegroundColor Cyan
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'tests\TEST-CONTINUE-PREFLIGHT.ps1')
    if($code -ne 0){
      Write-Host '[BLOCKED] Install skipped because Continue headless runtime is not ready.' -ForegroundColor Red
      exit $code
    }
    Write-Host '[model] Selecting an installed model that passes a real Continue Edit/Write smoke...' -ForegroundColor Cyan
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'tests\SELECT-WORKING-TOOL-MODEL.ps1')
    if($code -ne 0){
      Write-Host '[BLOCKED] Install skipped because no installed model passed Continue tool execution.' -ForegroundColor Red
      exit $code
    }
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'tests\RUN-ALL.ps1') -Arguments @('-Profile','Full')
    if($code -ne 0){
      Write-Host '[BLOCKED] Install skipped because Full regression is NO-GO.' -ForegroundColor Red
      exit $code
    }
    Write-Host '[gate] Real Continue tool smoke: selected model must actually edit a temporary main.md...' -ForegroundColor Cyan
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'tests\RUN-CONTINUE-TOOL-SMOKE.ps1')
    if($code -ne 0){
      Write-Host '[BLOCKED] Install skipped because Continue/model tool execution is not operational.' -ForegroundColor Red
      exit $code
    }
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'INSTALL.ps1')
    exit $code
  }
  'qualify' {
    if([string]::IsNullOrWhiteSpace($RealProject)){throw 'qualify requires -RealProject <path>'}
    $code=Invoke-DevScript -ScriptPath (Join-Path $root 'QUALIFY-RELEASE.ps1') -Arguments @('-RealProject',$RealProject)
    exit $code
  }
  'restore' {
    Need-Git
    $dirty=git status --porcelain
    if([string]::IsNullOrWhiteSpace(($dirty|Out-String))){
      Write-Host '[INFO] Working tree already clean.' -ForegroundColor Yellow
      break
    }
    git reset --hard HEAD
    git clean -fd
    Write-Host '[PASS] Restored last checkpoint.' -ForegroundColor Green
  }
}
