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
$stdout=Join-Path $tmp 'stdout.txt'
$stderr=Join-Path $tmp 'stderr.txt'
$target=Join-Path $tmp 'main.md'
Set-Content -LiteralPath $target -Encoding UTF8 -Value @(
  '# Draft',
  '',
  'One sentence.'
)
$before=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash

$prompt='Edit main.md. Keep "# Draft". Replace "One sentence." with exactly "Tool smoke passed: Continue edited this file." You MUST actually modify main.md using Edit or Write. Do not only describe the edit.'

# Official Continue CLI headless contract:
# --allow Edit/Write/MultiEdit makes write tools available without TUI approval.
$args=@(
  '--config',$ConfigPath,
  '--allow','Edit',
  '--allow','MultiEdit',
  '--allow','Write',
  '--exclude','Bash',
  '-p',$prompt
)

Write-Host "Continue CLI : $($cn.Source)" -ForegroundColor DarkGray
try{
  $ver=& cn --version 2>&1
  Write-Host "Continue ver : $($ver -join ' ')" -ForegroundColor DarkGray
}catch{}
Write-Host "Config       : $ConfigPath" -ForegroundColor DarkGray
Write-Host "Smoke repo   : $tmp" -ForegroundColor DarkGray

Push-Location $tmp
try{
  & cn @args 1> $stdout 2> $stderr
  $code=[int]$LASTEXITCODE
}finally{
  Pop-Location
}

$after=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
$content=Get-Content -LiteralPath $target -Raw

function Show-SmokeDiagnostics {
  Write-Host ''
  Write-Host '--- command ---' -ForegroundColor Yellow
  Write-Host ('cn ' + (($args | ForEach-Object {
    $v=[string]$_
    if($v -match '\s'){ '"' + ($v -replace '"','\"') + '"' } else { $v }
  }) -join ' '))
  Write-Host '--- stdout ---' -ForegroundColor Yellow
  if(Test-Path $stdout){Get-Content -LiteralPath $stdout|Select-Object -Last 200}else{Write-Host '<missing>'}
  Write-Host '--- stderr ---' -ForegroundColor Yellow
  if(Test-Path $stderr){Get-Content -LiteralPath $stderr|Select-Object -Last 200}else{Write-Host '<missing>'}
  Write-Host '--- effective config head ---' -ForegroundColor Yellow
  Get-Content -LiteralPath $ConfigPath|Select-Object -First 45
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
