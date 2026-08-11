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
    & (Join-Path $root 'VERIFY-PACKAGE.ps1')
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
    & (Join-Path $root 'tests\RUN-ALL.ps1') -Profile Full
    exit $LASTEXITCODE
  }
  'install' {
    & (Join-Path $root 'INSTALL.ps1')
    exit $LASTEXITCODE
  }
  'qualify' {
    if([string]::IsNullOrWhiteSpace($RealProject)){throw 'qualify requires -RealProject <path>'}
    & (Join-Path $root 'QUALIFY-RELEASE.ps1') -RealProject $RealProject
    exit $LASTEXITCODE
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
