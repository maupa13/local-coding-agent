[CmdletBinding()]
param([ValidateSet('All','EVAL-NODE-BUGFIX','EVAL-PY-FEATURE','EVAL-JAVA-REFACTOR','EVAL-PS-DOCS')][string]$Scenario='All',[string]$Model,[switch]$Decomposed,[switch]$KeepFixtures)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$matrix=Get-Content -LiteralPath (Join-Path $root 'tests\MODEL-EVAL-MATRIX.json') -Raw|ConvertFrom-Json
# Evaluate the candidate in this checkout. Using the previously installed copy
# could make a release pass while testing an older implementation.
$runtime=Join-Path $root 'powershell\LocalCodingAgent.psd1'
if(-not(Test-Path -LiteralPath $runtime)){throw 'Candidate module manifest is missing'}
$candidateModule=Import-Module $runtime -Force -PassThru -DisableNameChecking
if($Model){
  # Keep qualification isolated: override the in-memory candidate role without
  # changing the user's persisted default until the model passes hidden evals.
  & $candidateModule {param($SelectedModel)$script:AgentWorkModel=$SelectedModel} $Model
}
$runRoot=Join-Path ([IO.Path]::GetTempPath()) ('LocalCodingAgent\model-eval\'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $runRoot|Out-Null
$results=New-Object Collections.Generic.List[object]

$tasks=@{
  'EVAL-NODE-BUGFIX'='Implement REQ-01 through REQ-08 from docs/requirements.md. Read both src and both test files, reproduce failures, fix all root causes, add comprehensive node:test regression coverage, re-read changes, and run npm test until ExitCode: 0. Preserve package.json and CommonJS exports.'
  'EVAL-PY-FEATURE'='Implement the complete RateLimiter feature from docs/feature.md in src/rate_limiter.py using only the standard library. Preserve the exact constructor/method contract. Replace the placeholder with 6-10 concise deterministic pytest tests; explicitly import pytest, use the injected clock for boundary tests, and never sleep. Cover validation, per-key isolation, exact window boundary and selective reset without adding unrequested APIs. Run exactly `python -m pytest -q` until it passes.'
  'EVAL-JAVA-REFACTOR'='Refactor PriceCalculator according to docs/refactor.md. Preserve the public API and all behavior, extract independently testable rule logic without dependencies, and add meaningful JUnit regression tests for boundaries, validation and rounding. Run Maven tests and inspect the final diff.'
  'EVAL-PS-DOCS'='Analyze docs/requirements.md, src/Tools.psm1 and tests. Create AUDIT.md with a compliance matrix for every REQ-PS requirement, exact file:line evidence, severity/risk and minimal remediation. Do not modify implementation or tests.'
}

function Invoke-External([string]$File,[string[]]$Arguments,[string]$WorkingDirectory,[hashtable]$Environment=@{}){
  $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=$File;$psi.WorkingDirectory=$WorkingDirectory;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  # ProcessStartInfo.ArgumentList/Environment are unavailable on Windows
  # PowerShell 5.1 (.NET Framework). Quote arguments using the Windows CRT
  # convention and use EnvironmentVariables for cross-edition compatibility.
  $quoted=@($Arguments|ForEach-Object{
    $value=[string]$_
    if($value -notmatch '[\s"]'){$value}else{'"'+([regex]::Replace($value,'(\\*)"','$1$1\"') -replace '(\\+)$','$1$1')+'"'}
  })
  $psi.Arguments=$quoted -join ' '
  foreach($key in $Environment.Keys){$psi.EnvironmentVariables[$key]=[string]$Environment[$key]}
  $p=New-Object Diagnostics.Process;$p.StartInfo=$psi
  try{if(-not $p.Start()){throw "Could not start $File"};$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync();if(-not $p.WaitForExit(180000)){try{$p.Kill()}catch{};throw "$File timed out"};$text=($stdout.Result+"`n"+$stderr.Result).Trim();if($p.ExitCode -ne 0){throw "$File failed ($($p.ExitCode)):`n$text"};return $text}finally{$p.Dispose()}
}

foreach($case in @($matrix.scenarios|Where-Object{$Scenario -eq 'All' -or $_.id -eq $Scenario})){
  $fixture=Join-Path $runRoot ([string]$case.fixture)
  $started=Get-Date;$status='FAIL';$reason='';$diff='';$inputTokens=0;$outputTokens=0;$runtimeStatus='NOT_RUN'
  try{
    & (Join-Path $root 'tests\evals\NEW-MODEL-EVAL-FIXTURE.ps1') -Scenario $case.fixture -Path $fixture
    if($Decomposed -and [string]$case.id -eq 'EVAL-NODE-BUGFIX'){
      # Small local models perform better when one worker owns one coherent
      # concern. The final oracle still evaluates the fully assembled change.
      Invoke-AgentWorkflow -Workflow 'bugfix' -DisplayWorkflow 'bugfix-source' -Task @('Implement REQ-01 through REQ-07 from docs/requirements.md. Read both source files and existing tests. Modify only src/session-store.js and src/token-service.js. Use TypeError exactly where REQ-01 requires it. Preserve CommonJS exports. Run npm test until existing tests pass, then re-read both complete source files and report factual evidence.') -Headless -Managed -ProjectRoot $fixture
      Invoke-AgentWorkflow -Workflow 'test' -DisplayWorkflow 'test-coverage' -Task @('Implement REQ-08 from docs/requirements.md against the CURRENT implementation. Read both source files first. Modify only tests/session-store.test.js and tests/token-service.test.js. Add deterministic node:test coverage for validation, isolation, exact expiry boundary, selective revoke and bulk expiry. Never use sleeps or non-positive TTL to simulate expiry; inject and advance the provided clock. Run npm test until every public test passes.') -Headless -Managed -ProjectRoot $fixture
    }else{
      Invoke-AgentWorkflow -Workflow $case.workflow -DisplayWorkflow $case.workflow -Task @($tasks[[string]$case.id]) -Headless -Managed -ProjectRoot $fixture
    }
    $lastEvidence=& $candidateModule {$script:AgentLastEvidence}
    $runtimeStatePath=if($lastEvidence){Join-Path ([string]$lastEvidence) 'run.json'}else{''}
    if(-not $runtimeStatePath -or -not(Test-Path -LiteralPath $runtimeStatePath)){throw 'native runtime state evidence is missing'}
    $runtimeState=Get-Content -LiteralPath $runtimeStatePath -Raw|ConvertFrom-Json
    $runtimeStatus=[string]$runtimeState.state
    $inputTokens=[int]$runtimeState.promptTokens;$outputTokens=[int]$runtimeState.outputTokens
    if([string]$runtimeState.state -ne 'DONE'){throw "native runtime did not reach DONE: $($runtimeState.state)"}
    $diffFiles=@(& git -C $fixture diff --name-only)
    if($LASTEXITCODE -ne 0){throw 'git diff failed'}
    foreach($required in @($case.mustChange)){if($diffFiles -notcontains [string]$required){throw "model did not change required file: $required"}}
    $diff=(& git -C $fixture diff --no-ext-diff|Out-String)
    if([string]::IsNullOrWhiteSpace($diff)){throw 'model produced no diff'}
    switch([string]$case.id){
      'EVAL-NODE-BUGFIX' {
        $node=(Get-Command node.exe -ErrorAction Stop).Source
        Invoke-External $node @('--test','tests/session-store.test.js','tests/token-service.test.js') $fixture|Out-Null
        Invoke-External $node @('--test',(Join-Path $root 'tests\evals\hidden\node-bugfix.hidden.test.js')) $fixture @{EVAL_PROJECT=$fixture}|Out-Null
      }
      'EVAL-PY-FEATURE' {
        $python=(Get-Command python.exe -ErrorAction Stop).Source
        Invoke-External $python @('-m','pytest','-q','tests/test_rate_limiter.py') $fixture|Out-Null
        Invoke-External $python @('-m','pytest','-q',(Join-Path $root 'tests\evals\hidden\test_python_feature_hidden.py')) $fixture @{EVAL_PROJECT=$fixture}|Out-Null
        Invoke-External $python @((Join-Path $root 'tests\evals\lint\verify_python_quality.py'),$fixture) $fixture|Out-Null
      }
      'EVAL-JAVA-REFACTOR' {
        $hiddenTarget=Join-Path $fixture 'src\test\java\eval\PriceCalculatorContractTest.java'
        Copy-Item -LiteralPath (Join-Path $root 'tests\evals\hidden\PriceCalculatorContractTest.java') -Destination $hiddenTarget
        $mvn=(Get-Command mvn.cmd -ErrorAction Stop).Source
        Invoke-External $mvn @('-q','test') $fixture|Out-Null
      }
      'EVAL-PS-DOCS' { & (Join-Path $root 'tests\evals\hidden\Verify-Audit.ps1') -Project $fixture }
    }
    $status='PASS'
  }catch{$reason=$_.Exception.Message}
  $result=[pscustomobject]@{id=$case.id;language=$case.language;status=$status;runtimeStatus=$runtimeStatus;inputTokens=$inputTokens;outputTokens=$outputTokens;totalTokens=($inputTokens+$outputTokens);durationSeconds=[math]::Round(((Get-Date)-$started).TotalSeconds,1);fixture=$fixture;reason=$reason;diff=$diff}
  $results.Add($result);$result|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 (Join-Path $runRoot ($case.id+'.json'))
  Write-Host "[$status] $($case.id) · $($result.durationSeconds)s$(if($reason){' · '+$reason})" -ForegroundColor $(if($status -eq 'PASS'){'Green'}else{'Red'})
}
$results|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 (Join-Path $runRoot 'summary.json')
$failed=@($results|Where-Object status -ne 'PASS')
if(-not $KeepFixtures -and $failed.Count -eq 0){Remove-Item -LiteralPath $runRoot -Recurse -Force}
if($failed.Count){throw "MODEL RELEASE EVAL: NO-GO ($($failed.Count)/$($results.Count) failed). Evidence: $runRoot"}
Write-Host "MODEL RELEASE EVAL: GO ($($results.Count)/$($results.Count))." -ForegroundColor Green
