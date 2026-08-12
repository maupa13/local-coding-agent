[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'powershell\OllamaAgentLoop.ps1')
$hardwareConfig=Get-Content -LiteralPath (Join-Path $root 'config\hardware-profiles.json') -Raw|ConvertFrom-Json
$low=Resolve-NativeAgentHardwareSettings -Configuration $hardwareConfig -VramGb 6 -RamGb 16
$balanced=Resolve-NativeAgentHardwareSettings -Configuration $hardwareConfig -VramGb 12 -RamGb 32
$large=Resolve-NativeAgentHardwareSettings -Configuration $hardwareConfig -VramGb 24 -RamGb 64
if($low.profile -ne 'low-vram' -or $balanced.profile -ne 'balanced-12gb' -or $large.profile -ne 'large-vram'){throw '[FAIL] automatic hardware profile selection'}
$hardwareConfig.mode='balanced-12gb';$hardwareConfig.overrides=[pscustomobject]@{contextTokens=12288;runTokens=60000}
$custom=Resolve-NativeAgentHardwareSettings -Configuration $hardwareConfig -VramGb 24 -RamGb 64
if($custom.profile -ne 'balanced-12gb' -or $custom.contextTokens -ne 12288 -or $custom.runTokens -ne 60000 -or $custom.toolCalls -ne 140 -or $custom.commandTimeoutSeconds -ne 180){throw '[FAIL] explicit hardware profile/override'}
$invalidHardware=$hardwareConfig|ConvertTo-Json -Depth 10|ConvertFrom-Json;$invalidHardware.overrides=[pscustomobject]@{turns=1000}
try{Resolve-NativeAgentHardwareSettings -Configuration $invalidHardware -VramGb 10 -RamGb 32|Out-Null;throw '[FAIL] unsafe hardware override accepted'}catch{if($_.Exception.Message -eq '[FAIL] unsafe hardware override accepted' -or $_.Exception.Message -notmatch 'outside supported range'){throw '[FAIL] hardware range validation'}}
$moduleText=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
foreach($needle in @('OllamaAgentLoop.ps1','Invoke-AgentNativeManagedRun','managedRuntime','native-agent-transcript.json')){if(-not $moduleText.Contains($needle)){throw "[FAIL] managed native-loop integration missing: $needle"}}

$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-native-loop-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  $installedHardware=Join-Path $tmp 'hardware-profiles.json'
  Copy-Item -LiteralPath (Join-Path $root 'config\hardware-profiles.json') -Destination $installedHardware
  if((Get-NativeAgentHardwareSettings -ConfigurationPath $installedHardware).profile -notin @('low-vram','balanced-12gb','large-vram')){throw '[FAIL] installed-local hardware configuration'}
  & git -C $tmp init -q
  if($LASTEXITCODE -ne 0){throw '[FAIL] native-loop Git fixture initialization'}
  Set-Content -LiteralPath (Join-Path $tmp 'input.txt') -Encoding UTF8 -Value 'before'
  & git -C $tmp config user.email 'runtime-test@example.invalid'; & git -C $tmp config user.name 'Runtime Test'
  & git -C $tmp add input.txt; & git -C $tmp commit -q -m baseline
  if($LASTEXITCODE -ne 0){throw '[FAIL] native-loop Git fixture baseline commit'}

  $resolved=Resolve-NativeAgentPath -RepositoryRoot $tmp -RelativePath 'input.txt'
  if($resolved -ne (Join-Path $tmp 'input.txt')){throw '[FAIL] safe repository path resolution'}
  $gitBaseline=Get-NativeAgentGitState $tmp
  if(-not $gitBaseline.available -or -not $gitBaseline.head){throw '[FAIL] Git baseline evidence'}
  $gitClean=Test-NativeAgentGitAcceptance -RepositoryRoot $tmp -Baseline $gitBaseline
  if(-not $gitClean.Passed){throw "[FAIL] clean Git acceptance: $($gitClean.Reason)"}
  try{Resolve-NativeAgentPath -RepositoryRoot $tmp -RelativePath '..\escape.txt'|Out-Null;throw '[FAIL] traversal accepted'}catch{if($_.Exception.Message -eq '[FAIL] traversal accepted'){throw}}

  $write=Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='created.txt';content="hello`nworld"} -RepositoryRoot $tmp -ReadOnly:$false
  if(-not $write.Success -or -not(Test-Path (Join-Path $tmp 'created.txt'))){throw '[FAIL] write tool'}
  $read=Invoke-NativeAgentTool -Name 'read_file' -Arguments @{path='created.txt';start_line=1;end_line=2} -RepositoryRoot $tmp -ReadOnly:$false
  if(-not $read.Success -or $read.Output -notmatch 'hello' -or $read.Output -notmatch 'EOF'){throw '[FAIL] read tool/EOF contract'}
  $replace=Invoke-NativeAgentTool -Name 'replace_text' -Arguments @{path='created.txt';old_text='world';new_text='agent'} -RepositoryRoot $tmp -ReadOnly:$false
  if(-not $replace.Success -or (Get-Content (Join-Path $tmp 'created.txt') -Raw) -notmatch 'agent'){throw '[FAIL] replace tool'}
  try{Invoke-NativeAgentTool -Name 'replace_text' -Arguments @{path='created.txt';old_text='stale fragment';new_text='x'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] stale replace accepted'}catch{if($_.Exception.Message -eq '[FAIL] stale replace accepted' -or $_.Exception.Message -notmatch 'Current file:'){throw}}
  $lineEdit=Invoke-NativeAgentTool -Name 'replace_lines' -Arguments @{path='created.txt';start_line=2;end_line=2;content='line edit'} -RepositoryRoot $tmp
  if(-not $lineEdit.Success -or (Get-Content (Join-Path $tmp 'created.txt') -Raw) -notmatch 'line edit'){throw '[FAIL] replace-lines tool'}
  $rewrite=Invoke-NativeAgentTool -Name 'rewrite_file' -Arguments @{path='created.txt';content="coherent`nfile"} -RepositoryRoot $tmp
  if(-not $rewrite.Success -or (Get-Content (Join-Path $tmp 'created.txt') -Raw) -notmatch '^coherent'){throw '[FAIL] atomic rewrite tool'}
  try{Invoke-NativeAgentTool -Name 'rewrite_file' -Arguments @{path='missing.txt';content='x'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] rewrite created a missing file'}catch{if($_.Exception.Message -eq '[FAIL] rewrite created a missing file'){throw}}
  $large='a'*8000;$compact=Compress-NativeAgentToolOutput $large
  if($compact.Length -gt 3600 -or $compact.Length -ge $large.Length -or $compact -notmatch 'full output is preserved'){throw '[FAIL] bounded model tool context'}
  $history=Get-NativeAgentCompactedHistoryMessage @{role='assistant';content='';tool_calls=@(@{function=@{name='rewrite_file';arguments=@{path='large.txt';content=$large}}})}
  $historyContent=[string]$history.tool_calls[0].function.arguments.content
  if($historyContent.Length -ge 500 -or $historyContent -notmatch 'compacted'){throw '[FAIL] write payload history compaction'}
  $longHistory=New-Object Collections.ArrayList
  [void]$longHistory.Add(@{role='system';content='system'});[void]$longHistory.Add(@{role='user';content='task'})
  1..20|ForEach-Object{[void]$longHistory.Add(@{role='assistant';content="old $_"})}
  $active=@(Get-NativeAgentActiveMessages $longHistory -RecentMessages 6)
  if($active.Count -ne 9 -or $active[0].content -ne 'system' -or $active[1].content -ne 'task' -or $active[2].content -notmatch 'compacted' -or $active[-1].content -ne 'old 20'){throw '[FAIL] rolling active context'}
  if(Test-NativeAgentVerificationCommand 'git status'){throw '[FAIL] repository inspection accepted as verification'}
  if(-not(Test-NativeAgentVerificationCommand 'git diff --check')){throw '[FAIL] diff validation not recognized'}
  if(-not(Test-NativeAgentVerificationCommand 'npm test')){throw '[FAIL] test command not recognized'}
  if(-not(Test-NativeAgentLintCommand 'python -m ruff check .') -or -not(Test-NativeAgentLintCommand 'npm run lint') -or -not(Test-NativeAgentLintCommand 'cargo clippy --all-targets')){throw '[FAIL] lint command classification'}
  if(Test-NativeAgentLintCommand 'python -m pytest -q'){throw '[FAIL] tests classified as lint'}
  New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'lint-project')|Out-Null
  Set-Content -LiteralPath (Join-Path $tmp 'lint-project\pyproject.toml') -Encoding UTF8 -Value '[tool.ruff]'
  if((Get-NativeAgentLintCommand (Join-Path $tmp 'lint-project')) -ne 'python -m ruff check .'){throw '[FAIL] configured Python lint discovery'}
  $lintCases=@(
    @{name='npm';file='package.json';content='{"scripts":{"lint":"eslint ."}}';expected='npm run lint'},
    @{name='maven';file='pom.xml';content='<project><build><plugins><plugin><artifactId>maven-checkstyle-plugin</artifactId></plugin></plugins></build></project>';expected='mvn.cmd checkstyle:check'},
    @{name='gradle-java';file='build.gradle';content="plugins { id 'checkstyle' }";expected='gradlew.bat checkstyleMain'},
    @{name='gradle-kotlin';file='build.gradle.kts';content='plugins { id("io.gitlab.arturbosch.detekt") }';expected='gradlew.bat detekt'},
    @{name='cargo';file='Cargo.toml';content="[package]`nname='lint-fixture'`nversion='0.1.0'";expected='cargo clippy --all-targets --all-features -- -D warnings'}
  )
  foreach($case in $lintCases){$dir=Join-Path $tmp ('lint-'+$case.name);New-Item -ItemType Directory -Force $dir|Out-Null;Set-Content -LiteralPath (Join-Path $dir $case.file) -Encoding UTF8 -Value $case.content;if((Get-NativeAgentLintCommand $dir) -ne $case.expected){throw "[FAIL] configured $($case.name) lint discovery"}}
  Set-Content -LiteralPath (Join-Path $tmp 'test_placeholder.py') -Encoding UTF8 -Value "def test_placeholder():`n    assert True"
  $acceptance=Test-NativeAgentTaskAcceptance -RepositoryRoot $tmp -Task 'Replace the placeholder with 6-10 concise deterministic pytest tests.'
  if($acceptance.Passed -or $acceptance.Reason -notmatch 'placeholder' -or $acceptance.Reason -notmatch 'found 1'){throw '[FAIL] task acceptance did not reject placeholder/insufficient tests'}
  Set-Content -LiteralPath (Join-Path $tmp 'test_placeholder.py') -Encoding UTF8 -Value ((1..6|ForEach-Object{"def test_case_$($_)():`n    RateLimiter(1, 1)`n"}) -join "`n")
  $missingImport=Test-NativeAgentTaskAcceptance -RepositoryRoot $tmp -Task 'Implement RateLimiter(limit, window_seconds). Add 6-10 tests.'
  if($missingImport.Passed -or $missingImport.Reason -notmatch 'does not import'){throw '[FAIL] task acceptance missed tested contract type import'}
  Set-Content -LiteralPath (Join-Path $tmp 'test_placeholder.py') -Encoding UTF8 -Value ((1..6|ForEach-Object{"def test_case_$($_)():`n    assert True`n"}) -join "`n")
  if(-not (Test-NativeAgentTaskAcceptance -RepositoryRoot $tmp -Task 'Replace the placeholder with 6-10 concise deterministic pytest tests.').Passed){throw '[FAIL] task acceptance rejected satisfied test-count contract'}
  Set-Content -LiteralPath (Join-Path $tmp 'count.test.js') -Encoding UTF8 -Value ((1..11|ForEach-Object{"test('case $($_)', () => {});"}) -join "`n")
  $tooManyNodeTests=Test-NativeAgentTaskAcceptance -RepositoryRoot $tmp -Task 'Add 7-10 concise node tests.'
  if($tooManyNodeTests.Passed -or $tooManyNodeTests.Reason -notmatch 'task requires 7-10 tests'){throw '[FAIL] Node test-count upper bound was not enforced'}
  Remove-Item -LiteralPath (Join-Path $tmp 'count.test.js') -Force
  $snapshot=Get-NativeAgentInitialSnapshot -RepositoryRoot $tmp
  if($snapshot -notmatch 'test_placeholder.py' -or $snapshot -notmatch 'test_case_6' -or $snapshot -notmatch 'authoritative at turn 1'){throw '[FAIL] bounded initial repository snapshot'}
  if(-not(Test-NativeAgentShellCommand 'pytest')){throw '[FAIL] bare pytest not allowlisted'}
  if(Test-NativeAgentShellCommand 'python -m pytest tests 2>&1 | head -10'){throw '[FAIL] shell pipe/redirection accepted'}
  $pytestRun=Invoke-NativeAgentTool -Name 'shell' -Arguments @{command='pytest --version';timeout_seconds=30} -RepositoryRoot $tmp
  if($pytestRun.Output -notmatch 'pytest'){throw '[FAIL] pytest module fallback'}
  try{Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='created.txt';content='clobber'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] existing file overwrite accepted'}catch{if($_.Exception.Message -eq '[FAIL] existing file overwrite accepted'){throw};if($_.Exception.Message -notmatch 'rewrite_file'){throw '[FAIL] existing placeholder recovery guidance'}}
  New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'docs')|Out-Null
  Set-Content -LiteralPath (Join-Path $tmp 'docs\requirements.md') -Encoding UTF8 -Value 'REQ-01'
  $deduplicated=Resolve-NativeAgentPath -RepositoryRoot $tmp -RelativePath 'docs\docs\requirements.md'
  if($deduplicated -ne (Join-Path $tmp 'docs\requirements.md')){throw '[FAIL] duplicated path-segment recovery'}
  $searchFile=Invoke-NativeAgentTool -Name 'search_text' -Arguments @{path='docs\requirements.md';query='REQ-01';glob='docs\**\*.md'} -RepositoryRoot $tmp
  if($searchFile.Output -notmatch 'REQ-01'){throw '[FAIL] search file/glob normalization'}
  try{Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='blocked.txt';content='x'} -RepositoryRoot $tmp -ReadOnly|Out-Null;throw '[FAIL] readonly write accepted'}catch{if($_.Exception.Message -eq '[FAIL] readonly write accepted'){throw}}
  try{Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='package.json';content='{}'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] dependency write accepted'}catch{if($_.Exception.Message -eq '[FAIL] dependency write accepted'){throw}}
  if(Get-Command node.exe -ErrorAction SilentlyContinue){
    $badJs=Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='broken.js';content='function broken( {'} -RepositoryRoot $tmp
    if($badJs.Output -notmatch 'SYNTAX CHECK FAILED'){throw '[FAIL] post-edit JavaScript syntax diagnostic'}
    $badClock=Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='clock.test.js';content="let now = 1; const clock = () => ++now;`n"} -RepositoryRoot $tmp
    if($badClock.Output -notmatch 'TEST QUALITY FAILED' -or $badClock.Output -notmatch 'side-effect free'){throw '[FAIL] side-effectful JavaScript fake clock diagnostic'}
  }
  if(Get-Command python.exe -ErrorAction SilentlyContinue){
    $py=Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='test_missing_import.py';content="def test_x():`n    with pytest.raises(ValueError):`n        raise ValueError()`n"} -RepositoryRoot $tmp
    if($py.Output -notmatch 'pytest is used but not imported'){throw '[FAIL] Python post-edit test diagnostic'}
    $badPy=Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='broken.py';content='def broken('} -RepositoryRoot $tmp
    if($badPy.Output -notmatch 'SYNTAX CHECK FAILED'){throw '[FAIL] Python post-edit syntax diagnostic'}
  }
  $shell=Invoke-NativeAgentTool -Name 'shell' -Arguments @{command='git status';timeout_seconds=10} -RepositoryRoot $tmp
  if($shell.Output -notmatch '^ExitCode: \d+'){throw '[FAIL] shell exit-code capture'}
  try{Invoke-NativeAgentTool -Name 'shell' -Arguments @{command='git status --definitely-invalid-option';timeout_seconds=10} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] nonzero shell command accepted'}catch{if($_.Exception.Message -eq '[FAIL] nonzero shell command accepted'){throw}}
  try{Invoke-NativeAgentTool -Name 'shell' -Arguments @{command='cd /repo && python -m pytest -q'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] chained pytest accepted'}catch{if($_.Exception.Message -eq '[FAIL] chained pytest accepted' -or $_.Exception.Message -notmatch 'python -m pytest -q'){throw '[FAIL] actionable shell recovery guidance'}}
  try{Invoke-NativeAgentTool -Name 'shell' -Arguments @{command='cat tests/test_rate_limiter.py'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] shell file read accepted'}catch{if($_.Exception.Message -eq '[FAIL] shell file read accepted' -or $_.Exception.Message -notmatch 'read_file tool'){throw '[FAIL] shell file-read recovery guidance'}}
  try{Invoke-NativeAgentTool -Name 'replace_text' -Arguments @{path='created.txt';old_text='coherent';new_text='coherent'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] no-op replacement accepted'}catch{if($_.Exception.Message -eq '[FAIL] no-op replacement accepted' -or $_.Exception.Message -notmatch 'no-op'){throw '[FAIL] no-op replacement guard'}}
  Set-Content -LiteralPath (Join-Path $tmp 'commonjs.js') -Encoding UTF8 -Value "class Api {}`nmodule.exports = { Api };"
  try{Invoke-NativeAgentTool -Name 'rewrite_file' -Arguments @{path='commonjs.js';content='class Api {}'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] CommonJS export removal accepted'}catch{if($_.Exception.Message -eq '[FAIL] CommonJS export removal accepted' -or $_.Exception.Message -notmatch 'CommonJS'){throw '[FAIL] CommonJS semantic-anchor guard'}}

  $script:turn=0
  $fakeChat={param($Request,$OnChunk)
    $script:turn++
    if($Request.think -ne $false -or [int]$Request.options.num_predict -gt 4096 -or [double]$Request.options.temperature -ne 0){throw '[FAIL] bounded deterministic non-thinking tool request'}
    if($script:turn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='write_file';arguments=@{path='loop.txt';content='loop works'}}})};PromptTokens=100;OutputTokens=5;LoadMilliseconds=10;TotalMilliseconds=20}}
    if($script:turn -eq 2){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='shell';arguments=@{command='git diff --check';timeout_seconds=10}}})};PromptTokens=100;OutputTokens=5;LoadMilliseconds=0;TotalMilliseconds=15}}
    return [pscustomobject]@{Message=@{role='assistant';content="FINAL RESULT: PASS`nWORKFLOW: native-test`n`nSUMMARY`nDone`n`nVERIFICATION`nGit diff check passed.";tool_calls=@()};PromptTokens=50;OutputTokens=18;LoadMilliseconds=0;TotalMilliseconds=15}
  }
  $result=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'create loop.txt' -ChatInvoker $fakeChat -MaxTurns 4 -Quiet
  if(-not $result.Completed -or $result.TotalPromptTokens -ne 200 -or $result.TotalOutputTokens -ne 10){throw '[FAIL] loop completion/token accounting'}
  if($result.FinalOutput -notmatch '^TASK_COMPLETE' -or @($result.Transcript|Where-Object{$_.Role -eq 'runtime-finalizer'}).Count -ne 1){throw '[FAIL] verified mutation semantic finalizer'}
  if((Get-Content (Join-Path $tmp 'loop.txt') -Raw) -notmatch 'loop works'){throw '[FAIL] loop did not execute tool'}
  if($result.Transcript.Count -lt 2){throw '[FAIL] transcript persistence contract'}

  $script:readOnlyTurn=0
  $readOnlyChat={param($Request,$OnChunk)
    $script:readOnlyTurn++
    $readOnlyToolNames=@($Request.tools|ForEach-Object{$_.function.name})
    if(@($readOnlyToolNames|Where-Object{$_ -in @('write_file','rewrite_file','replace_text','replace_lines')}).Count){throw '[FAIL] mutation tools exposed in read-only mode'}
    if($Request.messages[1].content -notmatch 'READ-ONLY MODE'){throw '[FAIL] explicit read-only model instruction missing'}
    if($script:readOnlyTurn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='read_file';arguments=@{path='loop.txt'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:readOnlyTurn -eq 2){return [pscustomobject]@{Message=@{role='assistant';content="TASK_BLOCKED`nFINAL RESULT: BLOCKED`nSUMMARY`nCannot access repository.";tool_calls=@()};PromptTokens=10;OutputTokens=2}}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS`nSUMMARY`nRead loop.txt successfully.";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $readOnlyResult=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'read loop.txt' -ChatInvoker $readOnlyChat -MaxTurns 4 -ReadOnly -Quiet
  if(-not $readOnlyResult.Completed -or $script:readOnlyTurn -ne 3){throw '[FAIL] unsupported read-only BLOCKED was not rejected'}

  $script:multiReadTurn=0
  $multiReadChat={param($Request,$OnChunk)
    $script:multiReadTurn++
    if($script:multiReadTurn -le 5){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='read_file';arguments=@{path='loop.txt';start_line=1;end_line=$script:multiReadTurn}}})};PromptTokens=10;OutputTokens=2}}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS`nSUMMARY`nFive reads completed.";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $multiReadResult=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'inspect five regions' -ChatInvoker $multiReadChat -MaxTurns 7 -ReadOnly -Quiet
  if(-not $multiReadResult.Completed -or $script:multiReadTurn -ne 6){throw '[FAIL] successful read-only inspection was classified as no progress'}

  Set-Content -LiteralPath (Join-Path $tmp 'declared-second.txt') -Encoding UTF8 -Value 'second'
  $script:declaredReadTurn=0
  $declaredReadChat={param($Request,$OnChunk)
    $script:declaredReadTurn++
    if($script:declaredReadTurn -le 2){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='read_file';arguments=@{path=$(if($script:declaredReadTurn -eq 1){'loop.txt'}else{'declared-second.txt'})}}})};PromptTokens=10;OutputTokens=2}}
    if($Request.Contains('tools')){throw '[FAIL] tools remained open after declared unique reads'}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS`nSUMMARY`nTwo files inspected.";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $declaredReadResult=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'Read two files and report.' -ChatInvoker $declaredReadChat -MaxTurns 5 -ReadOnly -Quiet
  if(-not $declaredReadResult.Completed -or $script:declaredReadTurn -ne 3){throw '[FAIL] declared read-only inspection did not force deterministic completion'}

  $script:complianceTurn=0
  $complianceChat={param($Request,$OnChunk)
    $script:complianceTurn++
    if($script:complianceTurn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='read_file';arguments=@{path='loop.txt'}}})};PromptTokens=10;OutputTokens=2}}
    return [pscustomobject]@{Message=@{role='assistant';content='REQ-01 PASS - line 1 evidence. REQ-02 FAIL - line 2 evidence.';tool_calls=@()};PromptTokens=10;OutputTokens=10}
  }
  $complianceResult=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'Analyze documented REQ-01 and REQ-02 compliance.' -ChatInvoker $complianceChat -MaxTurns 4 -ReadOnly -Quiet
  if(-not $complianceResult.Completed -or $complianceResult.FinalOutput -notmatch 'COMPLIANCE MATRIX' -or $script:complianceTurn -ne 2){throw '[FAIL] semantic read-only compliance finalizer'}

  $script:mutationBlockTurn=0
  $mutationBlockChat={param($Request,$OnChunk)
    $script:mutationBlockTurn++
    if($script:mutationBlockTurn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='read_file';arguments=@{path='loop.txt'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:mutationBlockTurn -eq 2){return [pscustomobject]@{Message=@{role='assistant';content="TASK_BLOCKED`nFINAL RESULT: BLOCKED`nSUMMARY`nCannot access repository.";tool_calls=@()};PromptTokens=10;OutputTokens=2}}
    if($script:mutationBlockTurn -eq 3){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='write_file';arguments=@{path='mutation.txt';content='done'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:mutationBlockTurn -eq 4){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='shell';arguments=@{command='git diff --check'}}})};PromptTokens=10;OutputTokens=2}}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS`nSUMMARY`nImplemented.";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $mutationBlockResult=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'create mutation.txt' -ChatInvoker $mutationBlockChat -MaxTurns 6 -Quiet
  if(-not $mutationBlockResult.Completed -or $script:mutationBlockTurn -ne 4){throw '[FAIL] unsupported mutation BLOCKED was not rejected'}

  $script:repairRouteTurn=0
  $repairRouteChat={param($Request,$OnChunk)
    $script:repairRouteTurn++
    if($script:repairRouteTurn -eq 1){$prompt=($Request.messages.content -join "`n");if($prompt -notmatch 'DETERMINISTIC TIME-TEST CONTRACT'){throw '[FAIL] TTL task omitted deterministic time-test contract'};if($prompt -notmatch 'SPEC-BOUND TEST CONTRACT'){throw '[FAIL] test task omitted spec-bound test contract'}}
    if($script:repairRouteTurn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='write_file';arguments=@{path='repair.txt';content='bad'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:repairRouteTurn -eq 2){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='shell';arguments=@{command='npm test'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:repairRouteTurn -eq 3){$names=@($Request.tools|ForEach-Object{$_.function.name});if($names -notcontains 'read_file' -or $names -contains 'shell'){throw '[FAIL] failed verification did not expose bounded repair reads while blocking commands'};return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='read_file';arguments=@{path='repair.txt'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:repairRouteTurn -eq 4){$names=@($Request.tools|ForEach-Object{$_.function.name});if($names -contains 'shell'){throw '[FAIL] repair read incorrectly reopened verification before an edit'};return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='rewrite_file';arguments=@{path='repair.txt';content='fixed'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:repairRouteTurn -eq 5){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='shell';arguments=@{command='git diff --check'}}})};PromptTokens=10;OutputTokens=2}}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $repairRoute=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'repair TTL expiry and verify existing tests' -ChatInvoker $repairRouteChat -MaxTurns 7 -Quiet
  if(-not $repairRoute.Completed){throw '[FAIL] failed-verification edit-only route did not complete'}
  if(-not $repairRoute.Completed -or $script:repairRouteTurn -ne 5){throw '[FAIL] failed verification edit-only repair flow'}

  $script:textToolTurn=0
  $textToolChat={param($Request,$OnChunk)
    $script:textToolTurn++
    if($script:textToolTurn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='<tool_call>{"name":"write_file","arguments":{"path":"xml-tool.txt","content":"bridged"}}</tool_call>';tool_calls=@()};PromptTokens=10;OutputTokens=2}}
    if($script:textToolTurn -eq 2){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='shell';arguments=@{command='git diff --check'}}})};PromptTokens=10;OutputTokens=2}}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $textToolResult=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'create xml-tool.txt' -ChatInvoker $textToolChat -MaxTurns 4 -Quiet
  if(-not $textToolResult.Completed -or -not(Test-Path (Join-Path $tmp 'xml-tool.txt'))){throw '[FAIL] strict textual XML tool-call bridge'}

  $script:cycleTurn=0
  $cycleChat={param($Request,$OnChunk)
    $script:cycleTurn++
    if($Request.Contains('tools')){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='search_text';arguments=@{path='.';query='never'}}})};PromptTokens=10;OutputTokens=2}}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_BLOCKED`nFINAL RESULT: BLOCKED";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $cycle=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'cycle' -ChatInvoker $cycleChat -MaxTurns 20 -Quiet
  if($script:cycleTurn -gt 11 -or $cycle.Completed){throw '[FAIL] repeated non-consecutive tool signature cutoff'}

  $script:emptyTurns=0
  $emptyChat={param($Request,$OnChunk)$script:emptyTurns++;[pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@()};PromptTokens=10;OutputTokens=10}}
  $empty=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'empty' -ChatInvoker $emptyChat -MaxTurns 20 -Quiet
  if($script:emptyTurns -ne 3 -or $empty.Completed -or $empty.FinalOutput -notmatch 'TASK_BLOCKED'){throw '[FAIL] empty-turn fail-fast cutoff'}

  Set-Content -LiteralPath (Join-Path $tmp 'verify-pressure.txt') -Encoding UTF8 -Value 'zero'
  $script:pressureTurn=0
  $pressureChat={param($Request,$OnChunk)
    $script:pressureTurn++
    if($script:pressureTurn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='rewrite_file';arguments=@{path='verify-pressure.txt';content='one'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:pressureTurn -eq 2){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='rewrite_file';arguments=@{path='verify-pressure.txt';content='two'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:pressureTurn -eq 3){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='rewrite_file';arguments=@{path='verify-pressure.txt';content='three'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:pressureTurn -eq 4){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='rewrite_file';arguments=@{path='verify-pressure.txt';content='four'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:pressureTurn -eq 5){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='rewrite_file';arguments=@{path='verify-pressure.txt';content='five'}}})};PromptTokens=10;OutputTokens=2}}
    if($script:pressureTurn -eq 6){
      $toolNames=@($Request.tools|ForEach-Object{$_.function.name})
      if($toolNames.Count -ne 1 -or $toolNames[0] -ne 'shell'){throw '[FAIL] repeated writes did not force verification-only turn'}
      return [pscustomobject]@{Message=@{role='assistant';content='git diff --check';tool_calls=@()};PromptTokens=10;OutputTokens=2}
    }
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS";tool_calls=@()};PromptTokens=10;OutputTokens=2}
  }
  $pressure=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'pressure' -ChatInvoker $pressureChat -MaxTurns 8 -Quiet
  if(-not $pressure.Completed){throw '[FAIL] verification pressure flow did not complete'}
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host '[PASS] native Ollama loop safety, tools, continuation and exact token accounting' -ForegroundColor Green
