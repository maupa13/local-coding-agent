[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$toolchains=Get-Content (Join-Path $root 'config\toolchains.json') -Raw|ConvertFrom-Json
$javaHome=[string]$toolchains.java.javaHome
if(-not(Test-Path (Join-Path $javaHome 'bin\javac.exe'))){throw "Preferred Temurin 21 JDK is unavailable: $javaHome"}
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('lca-gold-python-'+[guid]::NewGuid().ToString('N'))
$javaFixture=Join-Path ([IO.Path]::GetTempPath()) ('lca-gold-java-'+[guid]::NewGuid().ToString('N'))
$kotlinFixture=Join-Path ([IO.Path]::GetTempPath()) ('lca-gold-kotlin-'+[guid]::NewGuid().ToString('N'))
$rustFixture=Join-Path ([IO.Path]::GetTempPath()) ('lca-gold-rust-'+[guid]::NewGuid().ToString('N'))
$frontendFixture=Join-Path ([IO.Path]::GetTempPath()) ('lca-gold-frontend-'+[guid]::NewGuid().ToString('N'))
try{
  $oldPreference=$ErrorActionPreference
  try{$ErrorActionPreference='Continue';& (Join-Path $root 'tests\evals\NEW-MODEL-EVAL-FIXTURE.ps1') -Scenario python-feature -Path $fixture}
  finally{$ErrorActionPreference=$oldPreference}
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\python-feature\src\rate_limiter.py') -Destination (Join-Path $fixture 'src\rate_limiter.py') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\python-feature\tests\test_rate_limiter.py') -Destination (Join-Path $fixture 'tests\test_rate_limiter.py') -Force
  $env:EVAL_PROJECT=$fixture
  Push-Location $fixture
  try{
    & python.exe -m pytest -q 'tests/test_rate_limiter.py';if($LASTEXITCODE -ne 0){throw '[FAIL] gold public tests'}
    & python.exe -m pytest -q (Join-Path $root 'tests\evals\hidden\test_python_feature_hidden.py');if($LASTEXITCODE -ne 0){throw '[FAIL] gold hidden oracle'}
    & python.exe (Join-Path $root 'tests\evals\lint\verify_python_quality.py') $fixture;if($LASTEXITCODE -ne 0){throw '[FAIL] gold lint oracle'}
  }finally{Pop-Location}

  try{$ErrorActionPreference='Continue';& (Join-Path $root 'tests\evals\NEW-MODEL-EVAL-FIXTURE.ps1') -Scenario java-refactor -Path $javaFixture}
  finally{$ErrorActionPreference=$oldPreference}
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\java-refactor\src\main\java\eval\PriceCalculator.java') -Destination (Join-Path $javaFixture 'src\main\java\eval\PriceCalculator.java') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\java-refactor\src\test\java\eval\PriceCalculatorTest.java') -Destination (Join-Path $javaFixture 'src\test\java\eval\PriceCalculatorTest.java') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\hidden\PriceCalculatorContractTest.java') -Destination (Join-Path $javaFixture 'src\test\java\eval\PriceCalculatorContractTest.java') -Force
  Push-Location $javaFixture
  try{
    $savedMavenJavaHome=$env:JAVA_HOME;$env:JAVA_HOME=$javaHome
    & mvn.cmd -q test;if($LASTEXITCODE -ne 0){throw '[FAIL] Java gold public/hidden tests'}
    & mvn.cmd -q checkstyle:check;if($LASTEXITCODE -ne 0){throw '[FAIL] Java gold Checkstyle'}
  }finally{$env:JAVA_HOME=$savedMavenJavaHome;Pop-Location}

  try{$ErrorActionPreference='Continue';& (Join-Path $root 'tests\evals\NEW-MODEL-EVAL-FIXTURE.ps1') -Scenario kotlin-feature -Path $kotlinFixture}
  finally{$ErrorActionPreference=$oldPreference}
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\kotlin-feature\src\main\kotlin\eval\Slugifier.kt') -Destination (Join-Path $kotlinFixture 'src\main\kotlin\eval\Slugifier.kt') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\kotlin-feature\src\test\kotlin\eval\SlugifierTest.kt') -Destination (Join-Path $kotlinFixture 'src\test\kotlin\eval\SlugifierTest.kt') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\hidden\SlugifierContractTest.kt') -Destination (Join-Path $kotlinFixture 'src\test\kotlin\eval\SlugifierContractTest.kt') -Force
  Push-Location $kotlinFixture
  try{
    $savedJavaHome=$env:JAVA_HOME;$env:JAVA_HOME=$javaHome
    & gradle --no-daemon -q clean test;if($LASTEXITCODE -ne 0){throw '[FAIL] Kotlin gold tests/compiler lint'}
    & gradle --no-daemon -q detekt;if($LASTEXITCODE -ne 0){throw '[FAIL] Kotlin gold Detekt'}
  }finally{$env:JAVA_HOME=$savedJavaHome;Pop-Location}

  try{$ErrorActionPreference='Continue';& (Join-Path $root 'tests\evals\NEW-MODEL-EVAL-FIXTURE.ps1') -Scenario rust-feature -Path $rustFixture}
  finally{$ErrorActionPreference=$oldPreference}
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\rust-feature\src\lib.rs') -Destination (Join-Path $rustFixture 'src\lib.rs') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\rust-feature\tests\port_test.rs') -Destination (Join-Path $rustFixture 'tests\port_test.rs') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\hidden\rust_port_contract.rs') -Destination (Join-Path $rustFixture 'tests\rust_port_contract.rs') -Force
  Push-Location $rustFixture
  try{
    $rustPreference=$ErrorActionPreference;$ErrorActionPreference='Continue'
    $cargoTest=@(& cargo test --quiet 2>&1|ForEach-Object{[string]$_});$cargoTestExit=$LASTEXITCODE
    $cargoLint=@(& cargo clippy --quiet --all-targets --all-features -- -D warnings 2>&1|ForEach-Object{[string]$_});$cargoLintExit=$LASTEXITCODE
    $ErrorActionPreference=$rustPreference
    if($cargoTestExit -ne 0){$cargoTest|Write-Host;throw '[FAIL] Rust gold public/hidden tests'}
    if($cargoLintExit -ne 0){$cargoLint|Write-Host;throw '[FAIL] Rust gold Clippy'}
  }finally{Pop-Location}

  try{$ErrorActionPreference='Continue';& (Join-Path $root 'tests\evals\NEW-MODEL-EVAL-FIXTURE.ps1') -Scenario frontend-feature -Path $frontendFixture}
  finally{$ErrorActionPreference=$oldPreference}
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\frontend-feature\src\index.html') -Destination (Join-Path $frontendFixture 'src\index.html') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\frontend-feature\src\styles.css') -Destination (Join-Path $frontendFixture 'src\styles.css') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\frontend-feature\src\disclosure.mjs') -Destination (Join-Path $frontendFixture 'src\disclosure.mjs') -Force
  Copy-Item -LiteralPath (Join-Path $root 'tests\evals\gold\frontend-feature\tests\disclosure.test.mjs') -Destination (Join-Path $frontendFixture 'tests\disclosure.test.mjs') -Force
  Push-Location $frontendFixture
  try{
    $node=(Get-Command node.exe -ErrorAction Stop).Source
    & $node --test 'tests/disclosure.test.mjs';if($LASTEXITCODE -ne 0){throw '[FAIL] frontend gold behavior tests'}
    & $node --check 'src/disclosure.mjs';if($LASTEXITCODE -ne 0){throw '[FAIL] frontend JS lint'}
    & $node (Join-Path $root 'tests\evals\lint\verify_frontend_quality.mjs') $frontendFixture;if($LASTEXITCODE -ne 0){throw '[FAIL] frontend HTML/CSS hidden quality'}
  }finally{Pop-Location}
}finally{
  Remove-Item Env:EVAL_PROJECT -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $javaFixture -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $kotlinFixture -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $rustFixture -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $frontendFixture -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host '[PASS] Python, JVM, Rust and frontend gold baselines: public + hidden + lint/static analysis' -ForegroundColor Green









