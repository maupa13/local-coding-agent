[CmdletBinding()]
param(
  [string]$ConfigPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(-not $ConfigPath){$ConfigPath=Join-Path $root 'config\config-agent.yaml'}
if(-not(Test-Path -LiteralPath $ConfigPath)){throw "Config not found: $ConfigPath"}
$cn=Get-Command cn -ErrorAction SilentlyContinue
if(-not $cn){throw "Continue CLI 'cn' not found."}

$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-cn-tool-smoke-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp|Out-Null
$git=Get-Command git -ErrorAction SilentlyContinue
if($git){
  & $git.Source -C $tmp init --quiet 2>$null
  if($LASTEXITCODE -ne 0){throw "Unable to initialize tool-smoke Git repository: $tmp"}
}
$stdout=Join-Path $tmp 'stdout.txt'
$stderr=Join-Path $tmp 'stderr.txt'
$target=Join-Path $tmp 'main.md'
Set-Content -LiteralPath $target -Encoding UTF8 -Value @(
  '# Draft',
  '',
  'One sentence.'
)
$before=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash

$prompt='Edit main.md using Edit or Write. Keep the heading unchanged. Replace the sentence One sentence. with: Tool smoke passed: Continue edited this file. You MUST actually modify main.md; do not only describe the edit.'

# Official Continue CLI headless contract:
# --allow Edit/Write/MultiEdit makes write tools available without TUI approval.
$cnArgs=@(
  '--config',$ConfigPath,
  '--verbose',
  '--allow','Edit',
  '--allow','MultiEdit',
  '--allow','Write',
  '--exclude','Bash',
  '-p',$prompt
)

Write-Host "Continue CLI : $($cn.Source)" -ForegroundColor DarkGray
try{
  $ver=& $cn.Source --version 2>&1
  Write-Host "Continue ver : $($ver -join ' ')" -ForegroundColor DarkGray
}catch{}
Write-Host "Config       : $ConfigPath" -ForegroundColor DarkGray
Write-Host "Smoke repo   : $tmp" -ForegroundColor DarkGray

Push-Location $tmp
try{
  # Continue CLI 1.5.x on Windows can exit 1 without output when its cn.ps1
  # wrapper is redirected to files. RUN-ALL already captures this script's
  # process output, so keep the CLI attached to the current streams.
  & $cn.Source @cnArgs
  $code=[int]$LASTEXITCODE
}finally{
  Pop-Location
}

$after=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
$content=Get-Content -LiteralPath $target -Raw

function Show-SmokeDiagnostics {
  Write-Host ''
  Write-Host '--- command ---' -ForegroundColor Yellow
  Write-Host ('cn ' + (($cnArgs | ForEach-Object {
    $v=[string]$_
    if($v -match '\s'){ '"' + ($v -replace '"','\"') + '"' } else { $v }
  }) -join ' '))
  Write-Host '--- stdout ---' -ForegroundColor Yellow
  Write-Host '<captured by the calling test harness>'
  Write-Host '--- stderr ---' -ForegroundColor Yellow
  Write-Host '<captured by the calling test harness>'
  Write-Host '--- effective config head ---' -ForegroundColor Yellow
  Get-Content -LiteralPath $ConfigPath|Select-Object -First 45
  if($code -ne 0){
    Write-Host '[DIAG] cn returned no output. Run .\tests\TEST-CONTINUE-PREFLIGHT.ps1; if it requests authentication, run: cn login' -ForegroundColor Cyan
  }
  Write-Host "--- diagnostic directory: $tmp ---" -ForegroundColor DarkGray
}

if($code -ne 0){
  Write-Host "[FAIL] Continue tool smoke: CLI exited $code" -ForegroundColor Red
  Show-SmokeDiagnostics
  exit 21
}
if($before -eq $after -or $content -notmatch 'Tool smoke passed: Continue edited this file\.'){
  Write-Host '[FAIL] Continue tool smoke: cn exited 0 but DID NOT EDIT main.md' -ForegroundColor Red
  Show-SmokeDiagnostics
  exit 22
}

Write-Host '[PASS] Continue real tool smoke: main.md was actually edited by cn' -ForegroundColor Green
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
exit 0
