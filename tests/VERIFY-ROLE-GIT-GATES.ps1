[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'powershell\OllamaAgentLoop.ps1')
$catalog=Get-Content (Join-Path $root 'workflows\catalog.json') -Raw|ConvertFrom-Json
foreach($role in @('feature','bugfix','refactor','test','release','analysis')){
  $entry=@($catalog.workflows|Where-Object name -eq $role)
  if($entry.Count -ne 1 -or -not(Test-Path (Join-Path $root ('workflows\'+$entry[0].file)))){throw "[FAIL] workflow role: $role"}
}
$generator=Get-Content (Join-Path $root 'tests\evals\NEW-MODEL-EVAL-FIXTURE.ps1') -Raw
foreach($fixture in @('python-feature','kotlin-feature','rust-feature','frontend-feature','node-bugfix','java-refactor')){if($generator -notmatch [regex]::Escape("'$fixture'")){throw "[FAIL] role fixture: $fixture"}}
foreach($scorer in @('tests\VERIFY-MODEL-EVAL-GOLD.ps1','tests\VERIFY-PLATFORM-GOLD.ps1','tests\VERIFY-RELEASE-GATE.ps1','tests\VERIFY-ARTIFACT-ANALYSIS.ps1')){if(-not(Test-Path (Join-Path $root $scorer))){throw "[FAIL] role scorer: $scorer"}}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-git-gates-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item -ItemType Directory -Force $tmp|Out-Null;& git -C $tmp init -q;& git -C $tmp config user.email git-gate@example.invalid;& git -C $tmp config user.name 'Git Gate'
  'baseline'|Set-Content -Encoding UTF8 (Join-Path $tmp 'tracked.txt');& git -C $tmp add .;& git -C $tmp commit -q -m baseline
  $baseline=Get-NativeAgentGitState $tmp;if(-not(Test-NativeAgentGitAcceptance $tmp $baseline).Passed){throw '[FAIL] clean Git baseline'}
  'user change'|Set-Content -Encoding UTF8 (Join-Path $tmp 'user.txt');$userState=Get-NativeAgentGitState $tmp
  'agent change'|Set-Content -Encoding UTF8 (Join-Path $tmp 'agent.txt');if(-not(Test-NativeAgentGitAcceptance $tmp $userState).Passed -or -not(Test-Path (Join-Path $tmp 'user.txt'))){throw '[FAIL] user-change preservation'}
  New-Item -ItemType Directory -Force (Join-Path $tmp '.aider.tags.cache.v4')|Out-Null;'x'|Set-Content (Join-Path $tmp '.aider.tags.cache.v4\tag')
  if((Test-NativeAgentGitAcceptance $tmp $baseline).Passed){throw '[FAIL] agent side effect accepted'}
  Remove-Item -LiteralPath (Join-Path $tmp '.aider.tags.cache.v4') -Recurse -Force
  'unauthorized history change'|Set-Content -Encoding UTF8 (Join-Path $tmp 'tracked.txt');& git -C $tmp add tracked.txt;& git -C $tmp commit -q -m unauthorized
  if((Test-NativeAgentGitAcceptance $tmp $baseline).Passed){throw '[FAIL] changed HEAD accepted'}
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host '[PASS] feature/bugfix/refactor/test/release/system-analysis roles and Git safety' -ForegroundColor Green


