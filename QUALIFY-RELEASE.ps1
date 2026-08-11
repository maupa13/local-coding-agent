[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RealProject,
  [switch]$InstallRecommendedModels,
  [switch]$KeepFixtures
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$exe=(Get-Command powershell.exe -ErrorAction Stop).Source



$diagnosticBase=if($env:LOCALAPPDATA){Join-Path $env:LOCALAPPDATA 'LocalCodingAgent\qualification'}else{Join-Path ([System.IO.Path]::GetTempPath()) 'LocalCodingAgent\qualification'}
$runStamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$logRoot=Join-Path $diagnosticBase ("$version-$runStamp")
New-Item -ItemType Directory -Force -Path $logRoot|Out-Null
$qualificationLog=Join-Path $logRoot ("QUALIFY-$version.log")
$environmentLog=Join-Path $logRoot ("ENV-$version.txt")
@(
  "Version: $version",
  "Started: $((Get-Date).ToString('o'))",
  "PackageRoot: $root",
  "RealProject: $RealProject",
  "PowerShell: $($PSVersionTable.PSVersion)",
  "PowerShellEdition: $($PSVersionTable.PSEdition)",
  "OS: $([Environment]::OSVersion.VersionString)",
  "User: $env:USERNAME",
  "HOME: $HOME",
  "PATH: $env:PATH",
  "Continue command: $((Get-Command cn -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source -ErrorAction SilentlyContinue))",
  "Node command: $((Get-Command node -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source -ErrorAction SilentlyContinue))",
  "npm command: $((Get-Command npm -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source -ErrorAction SilentlyContinue))",
  "git command: $((Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source -ErrorAction SilentlyContinue))"
)|Set-Content -Encoding UTF8 -LiteralPath $environmentLog
Start-Transcript -Path $qualificationLog -Force | Out-Null
Write-Host "[LOG] Qualification transcript: $qualificationLog" -ForegroundColor DarkGray
Write-Host "[LOG] Environment snapshot: $environmentLog" -ForegroundColor DarkGray

function Run-Step([string]$Name,[string]$Script,[string[]]$Arguments=@()){
  Write-Host "`n== $Name ==" -ForegroundColor Cyan
  $path=Join-Path $root $Script
  $started=Get-Date
  $safeName=($Name -replace '[^A-Za-z0-9_.-]','_')
  $stdoutLog=Join-Path $logRoot ("STEP-$safeName.stdout.log")
  $stderrLog=Join-Path $logRoot ("STEP-$safeName.stderr.log")

  Write-Host "[STEP] script: $path" -ForegroundColor DarkGray
  Write-Host "[STEP] args: $($Arguments -join ' ')" -ForegroundColor DarkGray
  Write-Host "[STEP] started: $($started.ToString('o'))" -ForegroundColor DarkGray
  Write-Host "[STEP] stdout: $stdoutLog" -ForegroundColor DarkGray
  Write-Host "[STEP] stderr: $stderrLog" -ForegroundColor DarkGray

  # Direct invocation preserves native PowerShell parameter binding. Previous
  # CLIXML runner passed the entire string array as one positional object and
  # could report exit 0 even after ParameterBindingException.
  $oldEap=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  try{
    & $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $path @Arguments 1> $stdoutLog 2> $stderrLog
    $code=$LASTEXITCODE
    if($null -eq $code){$code=0}
  }finally{
    $ErrorActionPreference=$oldEap
  }

  $stdout=if(Test-Path -LiteralPath $stdoutLog){Get-Content -LiteralPath $stdoutLog -Raw -ErrorAction SilentlyContinue}else{''}
  $stderr=if(Test-Path -LiteralPath $stderrLog){Get-Content -LiteralPath $stderrLog -Raw -ErrorAction SilentlyContinue}else{''}

  if(-not [string]::IsNullOrWhiteSpace($stdout)){
    foreach($line in @($stdout -split "`r?`n")){if($line -ne ''){Write-Host $line}}
  }
  if(-not [string]::IsNullOrWhiteSpace($stderr)){
    foreach($line in @($stderr -split "`r?`n")){if($line -ne ''){Write-Host "[stderr] $line" -ForegroundColor DarkYellow}}
  }

  $elapsed=[math]::Round(((Get-Date)-$started).TotalSeconds,2)
  Write-Host "[STEP] exit: $code · elapsed: ${elapsed}s" -ForegroundColor $(if($code -eq 0){'DarkGreen'}else{'Red'})
  if($code -ne 0){
    Write-Host "[LOG] Step stdout: $stdoutLog" -ForegroundColor Yellow
    Write-Host "[LOG] Step stderr: $stderrLog" -ForegroundColor Yellow
    Write-Host "[LOG] Full qualification transcript: $qualificationLog" -ForegroundColor Yellow
    throw "$Name failed with exit code $code."
  }
}

try{
if(-not(Test-Path -LiteralPath $RealProject -PathType Container)){throw "RealProject not found: $RealProject"}
Run-Step '1/7 PACKAGE' 'VERIFY-PACKAGE.ps1'
Run-Step '2/7 FULL REGRESSION' 'tests\RUN-ALL.ps1' @('-Profile','Full')
Write-Host "`n== 3/7 INSTALL $version ==" -ForegroundColor Cyan
$installArgs=@()
if($InstallRecommendedModels){$installArgs+='-InstallRecommendedModels'}
& $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'INSTALL.ps1') @installArgs
if($LASTEXITCODE -ne 0){throw "INSTALL failed with exit code $LASTEXITCODE."}
Run-Step '4/7 STARTUP / IDEA LAUNCHER SMOKE' 'tests\RUN-STARTUP-SMOKE.ps1' @('-Project',$RealProject)
Run-Step '5/7 REAL PROJECT / DOCTOR' 'tests\RUN-REAL-PROJECT-SMOKE.ps1' @('-Project',$RealProject)
$e2eArgs=@()
if($KeepFixtures){$e2eArgs=@('-KeepFixture')}
Run-Step '6/7 LIVE CODING E2E' 'tests\RUN-LIVE-E2E.ps1' $e2eArgs
Run-Step '7/7 REAL SHELL E2E' 'tests\RUN-SHELL-E2E.ps1' $e2eArgs
Write-Host "`nRELEASE VERDICT: GO" -ForegroundColor Green
Write-Host "[PASS] $version passed package, regression, install, startup, doctor, coding E2E and shell behavior qualification." -ForegroundColor Green
}finally{
  try{Stop-Transcript|Out-Null}catch{}
  Write-Host "[LOG] Qualification transcript: $qualificationLog" -ForegroundColor DarkGray
  Write-Host "[LOG] Environment snapshot: $environmentLog" -ForegroundColor DarkGray
}
