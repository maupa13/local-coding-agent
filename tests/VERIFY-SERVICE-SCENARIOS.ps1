[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$expected=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$runtimeHome=Join-Path $HOME '.continue\local-coding-agent'
$runtimeVersion=Join-Path $runtimeHome 'VERSION'
$launcher=Join-Path $runtimeHome 'IDEA-LAUNCH.ps1'
if(-not(Test-Path -LiteralPath $runtimeVersion)){throw 'Installed runtime missing.'}
$installed=(Get-Content -LiteralPath $runtimeVersion -Raw).Trim()
if($installed -ne $expected){throw "Installed runtime version $installed does not match candidate $expected."}
if(-not(Test-Path -LiteralPath $launcher)){throw "Installed launcher missing: $launcher"}
Import-Module (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Force

$project=Join-Path ([System.IO.Path]::GetTempPath()) ('LocalCodingAgent-service-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $project|Out-Null
Set-Content -LiteralPath (Join-Path $project 'package.json') -Encoding UTF8 -Value '{"name":"service-scenarios","private":true}'
$externalReadDir=Join-Path $root 'service-read-dir'
New-Item -ItemType Directory -Force -Path $externalReadDir|Out-Null

$help=& { agent-help } 6>&1 | Out-String
foreach($needle in @('/permissions','/add-read-dir','/review')){if($help -notmatch [regex]::Escape($needle)){throw "[FAIL] help output omitted $needle"}}

$workflows=& { agent-workflows } 6>&1 | Out-String
foreach($needle in @('Slash workflows','CORE','QUALITY','DOCS','/analysis','/feature','/bugfix','/review','/result')){if($workflows -notmatch [regex]::Escape($needle)){throw "[FAIL] workflow catalog omitted $needle"}}

$exe=(Get-Command powershell.exe -ErrorAction Stop).Source
$psi=New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName=$exe
$psi.Arguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$launcher+'" -Project "'+$project+'"'
$psi.WorkingDirectory=$project
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true
$psi.RedirectStandardInput=$true
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
$p=New-Object System.Diagnostics.Process
$p.StartInfo=$psi
try{
    if(-not $p.Start()){throw 'Failed to start installed CLI.'}
    $stdoutTask=$p.StandardOutput.ReadToEndAsync()
    $stderrTask=$p.StandardError.ReadToEndAsync()
    $p.StandardInput.WriteLine('/add-read-dir '+$externalReadDir)
    Start-Sleep -Milliseconds 750
    $p.StandardInput.WriteLine('/exit')
    $p.StandardInput.Close()
    if(-not $p.WaitForExit(30000)){try{$p.Kill()}catch{};throw 'Service scenario smoke did not exit after /exit within 30 seconds.'}
    $stdout=$stdoutTask.Result
    $stderr=$stderrTask.Result
    if($p.ExitCode -ne 0){throw "Service scenario smoke exited $($p.ExitCode). stderr: $stderr stdout: $stdout"}
    foreach($needle in @('project read-only directory added',$externalReadDir)){
        if($stdout -notmatch [regex]::Escape($needle)){throw "Service scenario smoke missing '$needle'. Output: $stdout"}
    }
    $settingsDir=Join-Path $runtimeHome 'projects'
    $settings=@()
    if(Test-Path -LiteralPath $settingsDir){
        $settings=@(Get-ChildItem -LiteralPath $settingsDir -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try{
                $json=Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
                if(([string]$json.projectRoot) -eq $project){[pscustomobject]@{Path=$_.FullName;Json=$json}}
            }catch{}
        })
    }
    if($settings.Count -ne 1){throw '[FAIL] project settings file for add-read-dir was not found after shell command'}
    $stored=@($settings[0].Json.readDirs)
    if($stored.Count -ne 1 -or $stored[0] -ne $externalReadDir){throw '[FAIL] add-read-dir did not persist the external read directory to project settings'}
    Write-Host '[PASS] service scenarios: permissions help, workflow catalog and add-read-dir persistence' -ForegroundColor Green
}finally{
    if($p){$p.Dispose()}
    Remove-Item -LiteralPath $externalReadDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $project -Recurse -Force -ErrorAction SilentlyContinue
}
