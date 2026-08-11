[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'powershell\OllamaAgentLoop.ps1')
$moduleText=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
foreach($needle in @('OllamaAgentLoop.ps1','Invoke-AgentNativeManagedRun','managedRuntime','native-agent-transcript.json')){if(-not $moduleText.Contains($needle)){throw "[FAIL] managed native-loop integration missing: $needle"}}

$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-native-loop-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  & git -C $tmp init -q
  if($LASTEXITCODE -ne 0){throw '[FAIL] native-loop Git fixture initialization'}
  Set-Content -LiteralPath (Join-Path $tmp 'input.txt') -Encoding UTF8 -Value 'before'

  $resolved=Resolve-NativeAgentPath -RepositoryRoot $tmp -RelativePath 'input.txt'
  if($resolved -ne (Join-Path $tmp 'input.txt')){throw '[FAIL] safe repository path resolution'}
  try{Resolve-NativeAgentPath -RepositoryRoot $tmp -RelativePath '..\escape.txt'|Out-Null;throw '[FAIL] traversal accepted'}catch{if($_.Exception.Message -eq '[FAIL] traversal accepted'){throw}}

  $write=Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='created.txt';content="hello`nworld"} -RepositoryRoot $tmp -ReadOnly:$false
  if(-not $write.Success -or -not(Test-Path (Join-Path $tmp 'created.txt'))){throw '[FAIL] write tool'}
  $read=Invoke-NativeAgentTool -Name 'read_file' -Arguments @{path='created.txt';start_line=1;end_line=2} -RepositoryRoot $tmp -ReadOnly:$false
  if(-not $read.Success -or $read.Output -notmatch 'hello'){throw '[FAIL] read tool'}
  $replace=Invoke-NativeAgentTool -Name 'replace_text' -Arguments @{path='created.txt';old_text='world';new_text='agent'} -RepositoryRoot $tmp -ReadOnly:$false
  if(-not $replace.Success -or (Get-Content (Join-Path $tmp 'created.txt') -Raw) -notmatch 'agent'){throw '[FAIL] replace tool'}
  $lineEdit=Invoke-NativeAgentTool -Name 'replace_lines' -Arguments @{path='created.txt';start_line=2;end_line=2;content='line edit'} -RepositoryRoot $tmp
  if(-not $lineEdit.Success -or (Get-Content (Join-Path $tmp 'created.txt') -Raw) -notmatch 'line edit'){throw '[FAIL] replace-lines tool'}
  try{Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='created.txt';content='clobber'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] existing file overwrite accepted'}catch{if($_.Exception.Message -eq '[FAIL] existing file overwrite accepted'){throw}}
  New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'docs')|Out-Null
  Set-Content -LiteralPath (Join-Path $tmp 'docs\requirements.md') -Encoding UTF8 -Value 'REQ-01'
  $deduplicated=Resolve-NativeAgentPath -RepositoryRoot $tmp -RelativePath 'docs\docs\requirements.md'
  if($deduplicated -ne (Join-Path $tmp 'docs\requirements.md')){throw '[FAIL] duplicated path-segment recovery'}
  $searchFile=Invoke-NativeAgentTool -Name 'search_text' -Arguments @{path='docs\requirements.md';query='REQ-01';glob='docs\**\*.md'} -RepositoryRoot $tmp
  if($searchFile.Output -notmatch 'REQ-01'){throw '[FAIL] search file/glob normalization'}
  try{Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='blocked.txt';content='x'} -RepositoryRoot $tmp -ReadOnly|Out-Null;throw '[FAIL] readonly write accepted'}catch{if($_.Exception.Message -eq '[FAIL] readonly write accepted'){throw}}
  try{Invoke-NativeAgentTool -Name 'write_file' -Arguments @{path='package.json';content='{}'} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] dependency write accepted'}catch{if($_.Exception.Message -eq '[FAIL] dependency write accepted'){throw}}
  $shell=Invoke-NativeAgentTool -Name 'shell' -Arguments @{command='git status';timeout_seconds=10} -RepositoryRoot $tmp
  if($shell.Output -notmatch '^ExitCode: \d+'){throw '[FAIL] shell exit-code capture'}
  try{Invoke-NativeAgentTool -Name 'shell' -Arguments @{command='git status --definitely-invalid-option';timeout_seconds=10} -RepositoryRoot $tmp|Out-Null;throw '[FAIL] nonzero shell command accepted'}catch{if($_.Exception.Message -eq '[FAIL] nonzero shell command accepted'){throw}}

  $script:turn=0
  $fakeChat={param($Request,$OnChunk)
    $script:turn++
    if($script:turn -eq 1){return [pscustomobject]@{Message=@{role='assistant';content='';tool_calls=@(@{function=@{name='write_file';arguments=@{path='loop.txt';content='loop works'}}})};PromptTokens=120;OutputTokens=8;LoadMilliseconds=10;TotalMilliseconds=20}}
    return [pscustomobject]@{Message=@{role='assistant';content="TASK_COMPLETE`nFINAL RESULT: PASS`nWORKFLOW: native-test`n`nSUMMARY`nDone";tool_calls=@()};PromptTokens=150;OutputTokens=20;LoadMilliseconds=0;TotalMilliseconds=15}
  }
  $result=Invoke-NativeOllamaAgentLoop -RepositoryRoot $tmp -Model 'fake' -SystemPrompt 'test' -Task 'create loop.txt' -ChatInvoker $fakeChat -MaxTurns 4 -Quiet
  if(-not $result.Completed -or $result.TotalPromptTokens -ne 270 -or $result.TotalOutputTokens -ne 28){throw '[FAIL] loop completion/token accounting'}
  if((Get-Content (Join-Path $tmp 'loop.txt') -Raw) -notmatch 'loop works'){throw '[FAIL] loop did not execute tool'}
  if($result.Transcript.Count -lt 2){throw '[FAIL] transcript persistence contract'}
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host '[PASS] native Ollama loop safety, tools, continuation and exact token accounting' -ForegroundColor Green
