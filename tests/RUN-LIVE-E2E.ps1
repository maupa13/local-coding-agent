[CmdletBinding()]
param(
  [string]$FixturePath='C:\AI\local-coding-agent-release-e2e',
  [switch]$KeepFixture
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$runtimeHome=Join-Path $HOME '.continue\local-coding-agent'
$runtimeModule=Join-Path $runtimeHome 'LocalCodingAgent.psm1'
$runtimeVersion=Join-Path $runtimeHome 'VERSION'
$expectedVersion=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if(-not(Test-Path -LiteralPath $runtimeModule)){throw 'Installed runtime not found. Install the candidate build first.'}
if(-not(Test-Path -LiteralPath $runtimeVersion)){throw 'Installed runtime VERSION marker missing. Reinstall the candidate build.'}
$installedVersion=(Get-Content -LiteralPath $runtimeVersion -Raw).Trim()
if($installedVersion -ne $expectedVersion){throw "Installed runtime version $installedVersion does not match candidate $expectedVersion."}
foreach($cmd in @('git','node','npm')){if(-not(Get-Command $cmd -ErrorAction SilentlyContinue)){throw "Required command missing for live E2E: $cmd"}}
& (Join-Path $root 'tests\NEW-RELEASE-E2E-REPO.ps1') -Path $FixturePath
Import-Module $runtimeModule -Force
$evidenceRoot=Join-Path $runtimeHome 'evidence'
$started=Get-Date
$resultRoot=Join-Path ([System.IO.Path]::GetTempPath()) 'LocalCodingAgent\release-e2e'
$script:LiveE2EFailed=$false
New-Item -ItemType Directory -Force -Path $resultRoot|Out-Null

function Get-LatestRun([string]$Project,[string]$Workflow,[DateTime]$After){
  $items=@()
  if(Test-Path -LiteralPath $evidenceRoot){
    $files=Get-ChildItem -LiteralPath $evidenceRoot -Filter 'session.json' -File -Recurse -ErrorAction SilentlyContinue
    foreach($file in $files){
      try{
        $session=Get-Content -LiteralPath $file.FullName -Raw|ConvertFrom-Json
        if(([string]$session.repositoryRoot) -ne $Project){continue}
        if(([string]$session.workflow) -ne $Workflow){continue}
        $time=[DateTime]::Parse([string]$session.startedAt)
        if($time -lt $After){continue}
        $items += [pscustomobject]@{Session=$session;Directory=$file.DirectoryName;StartedAt=$time}
      }catch{}
    }
  }
  return @($items|Sort-Object StartedAt -Descending|Select-Object -First 1)
}

function Assert-Run([string]$Workflow,[DateTime]$After,[string[]]$AllowedStatuses,[switch]$RequireCompliance,[switch]$RequireQualityPass){
  $found=@(Get-LatestRun -Project $FixturePath -Workflow $Workflow -After $After)
  if($found.Count -ne 1){throw "No evidence found for /$Workflow after $After"}
  $item=$found[0]
  $status=([string]$item.Session.semanticStatus).ToUpperInvariant()
  if($AllowedStatuses -notcontains $status){throw "/$Workflow semantic status $status is not acceptable. Evidence: $($item.Directory)"}
  if(-not $item.Session.before.isGit -or -not $item.Session.after.isGit){throw "/$Workflow did not record Git repository state correctly."}
  $final=Join-Path $item.Directory 'final-result.txt'
  if(-not(Test-Path -LiteralPath $final)){throw "/$Workflow final-result.txt missing."}
  $text=Get-Content -LiteralPath $final -Raw
  if($RequireCompliance -and $text -notmatch '(?i)COMPLIANCE MATRIX'){throw '/analysis did not produce COMPLIANCE MATRIX.'}
  if($RequireCompliance -and $text -notmatch '(?i)REQ-03'){throw '/analysis did not inspect REQ-03.'}
  if($RequireQualityPass){
    $quality=([string]$item.Session.qualityStatus).ToUpperInvariant()
    if($quality -notin @('PASS','PASS WITH WARNINGS')){throw "/$Workflow quality status $quality is not release-qualified."}
  }
  Write-Host "[PASS] live /$Workflow -> $status" -ForegroundColor Green
  return $item
}


function Write-EvidenceDiagnostics {
  param([string]$Workflow,[DateTime]$After)
  Write-Host "`n========== LIVE E2E DIAGNOSTICS ==========" -ForegroundColor Yellow
  Write-Host "FixturePath: $FixturePath" -ForegroundColor Yellow
  Write-Host "Fixture exists: $(Test-Path -LiteralPath $FixturePath)" -ForegroundColor Yellow
  Write-Host "RuntimeModule: $runtimeModule" -ForegroundColor Yellow
  Write-Host "ExpectedVersion: $expectedVersion" -ForegroundColor Yellow
  Write-Host "InstalledVersion: $installedVersion" -ForegroundColor Yellow

  if(Test-Path -LiteralPath $FixturePath){
    Write-Host "`n[fixture tree]" -ForegroundColor DarkYellow
    Get-ChildItem -LiteralPath $FixturePath -Recurse -File -ErrorAction SilentlyContinue |
      Select-Object -First 80 |
      ForEach-Object { Write-Host ("  " + $_.FullName) }

    $req=Join-Path $FixturePath 'docs\requirements.md'
    Write-Host "`n[requirements.md] exists=$(Test-Path -LiteralPath $req)" -ForegroundColor DarkYellow
    if(Test-Path -LiteralPath $req){
      Get-Content -LiteralPath $req -ErrorAction SilentlyContinue |
        Select-Object -First 80 |
        ForEach-Object { Write-Host ("  " + $_) }
    }

    Write-Host "`n[git status]" -ForegroundColor DarkYellow
    try{git -C $FixturePath status --porcelain=v1 -uall 2>&1|ForEach-Object{Write-Host ("  "+$_)}}catch{Write-Host ("  ERROR: "+$_.Exception.Message)}
  }

  $found=@(Get-LatestRun -Project $FixturePath -Workflow $Workflow -After $After)
  if($found.Count -gt 0){
    $item=$found[0]
    Write-Host "`n[evidence] $($item.Directory)" -ForegroundColor Yellow
    foreach($name in @(
      'session.json',
      'repository-inventory.md',
      'model-output.txt',
      'compliance-recovery-output.txt',
      'compliance-requirements-diagnostic.txt',
      'capture-diagnostic.txt',
      'native-warnings.txt',
      'native-stderr.txt',
      'wrapper-finalized.json',
      'final-result.txt',
      'quality-report.txt'
    )){
      $path=Join-Path $item.Directory $name
      Write-Host "`n--- $name · exists=$(Test-Path -LiteralPath $path) ---" -ForegroundColor DarkYellow
      if(Test-Path -LiteralPath $path){
        Get-Content -LiteralPath $path -ErrorAction SilentlyContinue |
          Select-Object -Last 120 |
          ForEach-Object { Write-Host $_ }
      }
    }
  }else{
    Write-Host "[evidence] No matching session found for /$Workflow after $After" -ForegroundColor Red
  }
  Write-Host "========== END DIAGNOSTICS ==========`n" -ForegroundColor Yellow
}

function Invoke-LiveNative {
  param([Parameter(Mandatory=$true)][scriptblock]$Command,[string]$Name='native command')
  $oldEap=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  try{
    $output=& $Command 2>&1
    $code=$LASTEXITCODE
    if($null -eq $code){$code=0}
    if($code -ne 0){throw "$Name failed with exit code $code. Output: $($output|Out-String)"}
    return @($output)
  }finally{$ErrorActionPreference=$oldEap}
}

try{
  $currentWorkflow='analysis'
  $currentStarted=Get-Date
  $t1=$currentStarted
  Invoke-AgentWorkflow -Workflow 'analyze' -DisplayWorkflow 'analysis' -Task @('Проанализируй папку docs и проект на соответствие документации. Построй полную COMPLIANCE MATRIX для каждого REQ с evidence из кода и тестов. Ничего не меняй.') -ReadOnly -Headless -Managed -ProjectRoot $FixturePath
  $analysis=Assert-Run -Workflow 'analysis' -After $t1 -AllowedStatuses @('PASS','PARTIAL','FAIL') -RequireCompliance
  $afterAnalysis=((Invoke-LiveNative -Name 'git status after analysis' -Command { git -C $FixturePath status --porcelain })|Out-String).Trim()
  if($afterAnalysis){throw "Read-only /analysis modified the fixture: $afterAnalysis"}
  Write-Host '[PASS] /analysis preserved clean working tree' -ForegroundColor Green

  $currentWorkflow='bugfix'
  $currentStarted=Get-Date
  $t2=$currentStarted
  Invoke-AgentWorkflow -Workflow 'bugfix' -DisplayWorkflow 'bugfix' -Task @('Исправь дефект REQ-03 в SessionStore.clear() и добавь недостающий regression test для clear. Не меняй требования. Доведи npm test до PASS.') -Headless -Managed -ProjectRoot $FixturePath
  $bugfix=Assert-Run -Workflow 'bugfix' -After $t2 -AllowedStatuses @('PASS') -RequireQualityPass

  Push-Location $FixturePath
  try{
    [void](Invoke-LiveNative -Name 'npm test after bugfix' -Command { npm test })
    $diff=((Invoke-LiveNative -Name 'git diff after bugfix' -Command { git diff -- src/session-store.js tests/session-store.test.js })|Out-String)
    if([string]::IsNullOrWhiteSpace($diff)){throw 'Bugfix produced no source/test diff.'}
    if($diff -notmatch 'clear'){throw 'Bugfix diff does not contain clear behavior.'}
  }finally{Pop-Location}
  Write-Host '[PASS] fixture regression test passes after real agent bugfix' -ForegroundColor Green

  $beforeReview=((Invoke-LiveNative -Name 'git diff before review' -Command { git -C $FixturePath diff --no-ext-diff })|Out-String)
  $currentWorkflow='review'
  $currentStarted=Get-Date
  $t3=$currentStarted
  Invoke-AgentWorkflow -Workflow 'review' -DisplayWorkflow 'review' -Task @('Проведи независимый read-only review текущего diff относительно docs/requirements.md. Проверь correctness и regression coverage. Ничего не меняй.') -ReadOnly -Headless -Managed -ProjectRoot $FixturePath
  $review=Assert-Run -Workflow 'review' -After $t3 -AllowedStatuses @('PASS','PARTIAL')
  $afterReview=((Invoke-LiveNative -Name 'git diff after review' -Command { git -C $FixturePath diff --no-ext-diff })|Out-String)
  if($afterReview -ne $beforeReview){throw 'Read-only /review changed the working tree diff.'}
  Write-Host '[PASS] /review preserved bugfix diff exactly' -ForegroundColor Green

  $summary=[ordered]@{
    version=$expectedVersion
    fixture=$FixturePath
    generatedAt=(Get-Date).ToString('o')
    analysisEvidence=$analysis.Directory
    bugfixEvidence=$bugfix.Directory
    reviewEvidence=$review.Directory
    verdict='PASS'
  }
  $summary|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 (Join-Path $resultRoot 'live-e2e-latest.json')
  Write-Host '[PASS] LIVE E2E: compliance -> bugfix -> tests -> review' -ForegroundColor Green
}catch{
  Write-Host ("[FAIL] LIVE E2E exception: " + $_.Exception.Message) -ForegroundColor Red
  Write-EvidenceDiagnostics -Workflow $currentWorkflow -After $currentStarted
  $failureMarker=Join-Path $resultRoot 'live-e2e-last-failure.txt'
  @(
    "Version: $expectedVersion",
    "Workflow: $currentWorkflow",
    "Fixture: $FixturePath",
    "Time: $((Get-Date).ToString('o'))",
    "Error: $($_.Exception.Message)",
    "EvidenceRoot: $evidenceRoot"
  )|Set-Content -Encoding UTF8 -LiteralPath $failureMarker
  Write-Host "[LOG] Failure marker: $failureMarker" -ForegroundColor Yellow
  Write-Host "[LOG] Fixture preserved automatically after failure: $FixturePath" -ForegroundColor Yellow
  $script:LiveE2EFailed=$true
  throw
}finally{
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
  if(-not $KeepFixture -and -not $script:LiveE2EFailed){
    Remove-Item -LiteralPath $FixturePath -Recurse -Force -ErrorAction SilentlyContinue
  }
}
