[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$failed=0
function Check([string]$Name,[scriptblock]$Test){try{& $Test;Write-Host "[PASS] $Name" -ForegroundColor Green}catch{$script:failed++;Write-Host "[FAIL] $Name - $($_.Exception.Message)" -ForegroundColor Red}}
$required=@(
 'VERSION','README.md','CHANGELOG.md','BETA-ACCEPTANCE.md','RC-ACCEPTANCE.md','RELEASE-ACCEPTANCE.md','MAINTENANCE.md','INSTALL.ps1','UNINSTALL.ps1','ACTIVATE.ps1','IDEA-INTEGRATE.ps1','integrations\IDEA-LAUNCH.ps1',
 'config\config.yaml','config\config-agent.yaml','config\config-agent-fast.yaml','config\permissions.yaml',
 'powershell\LocalCodingAgent.psm1','workflows\catalog.json',
 'tests\VERIFY-MANAGED-SHELL.ps1','tests\VERIFY-CONTEXT-BUDGET.ps1','tests\VERIFY-ENGINEERING-GUARDS.ps1','tests\VERIFY-QUALITY-ENGINE.ps1','tests\VERIFY-COMPACT-UI.ps1','tests\VERIFY-PRODUCT-CLI.ps1','tests\VERIFY-LAUNCHER-MODELS-SKILLS.ps1','tests\VERIFY-INSTALL-FAIL-CLOSED.ps1','tests\VERIFY-IDEA-INTEGRATION.ps1','tests\VERIFY-MULTIPROJECT-UX.ps1','tests\VERIFY-CODING-CORE.ps1','tests\VERIFY-ENGINEERING-QUALITY.ps1','tests\VERIFY-BETA-RELIABILITY.ps1','tests\VERIFY-REGRESSION-HISTORY.ps1','tests\VERIFY-TEST-MATRIX.ps1','tests\VERIFY-TEST-MATRIX-SCHEMA.ps1','tests\VERIFY-UTF8-CAPTURE.ps1','tests\VERIFY-WRAPPER-FINALIZER.ps1','tests\VERIFY-TERMINAL-COMPLIANCE-REPORT.ps1','tests\VERIFY-COMPLIANCE-REQUIREMENT-EXTRACTION.ps1','tests\VERIFY-COMPLIANCE-FINALIZER-NONZERO.ps1','tests\VERIFY-DIAGNOSTIC-LOGGING.ps1','tests\VERIFY-LOG-ISOLATION.ps1','tests\VERIFY-EXTRACTOR-STAGED-DIAGNOSTICS.ps1','tests\VERIFY-QUALIFY-ARGUMENT-BINDING.ps1','tests\VERIFY-COMPLIANCE-MATRIX-LAYOUT.ps1','tests\VERIFY-DEV-WORKSPACE.ps1','tests\VERIFY-PS51-PATH-CHARS.ps1','tests\VERIFY-FILESYSTEM-FIRST-INVENTORY.ps1','tests\VERIFY-NON-GIT-INVENTORY.ps1','tests\VERIFY-DOC-EDIT-USER-JOURNEY.ps1','tests\VERIFY-DOC-EDIT-ROUTING.ps1','tests\VERIFY-PROJECT-ROOT-SELECTION.ps1','tests\VERIFY-DEV-STRICTMODE-EXITCODE.ps1','tests\VERIFY-RUN-CHANGE-ACCOUNTING.ps1','tests\VERIFY-UX-RUNTIME.ps1','tests\VERIFY-PS-VARIABLE-COLON-HYGIENE.ps1','tests\VERIFY-COMPLIANCE-RUNTIME-SELFTEST.ps1','tests\VERIFY-STRICTMODE-TEST-HYGIENE.ps1','tests\VERIFY-COMPLIANCE-FINALIZER-CONTRACT.ps1','tests\VERIFY-SANDBOX-VERSION.ps1','tests\VERIFY-HARNESS-SMOKE.ps1','tests\VERIFY-NATIVE-STDERR.ps1','tests\VERIFY-RELEASE-GATE.ps1','tests\VERIFY-EMPTY-CAPTURE-RECOVERY.ps1','tests\VERIFY-FIXTURE-GENERATORS.ps1','tests\VERIFY-OUTPUT-ISOLATION.ps1','tests\RUN-ALL.ps1','tests\RUN-STARTUP-SMOKE.ps1','tests\RUN-REAL-PROJECT-SMOKE.ps1','tests\RUN-CONTINUE-TOOL-SMOKE.ps1','tests\RUN-LIVE-E2E.ps1','tests\RUN-SHELL-E2E.ps1','tests\RUN-RELEASE-QUALIFICATION.ps1','tests\TEST-MATRIX.json','tests\SCENARIO-MATRIX.json','QUALIFY-RELEASE.ps1','skills\documentation-compliance.md',
 'skills\spec-driven-feature.md','skills\systematic-debugging.md','skills\verification-before-completion.md','tests\VERIFY-PS51-COMPAT.ps1',
 'tests\NEW-ACCEPTANCE-REPO.ps1','tests\NEW-RUST-GUARD-REPO.ps1','tests\NEW-DOC-SOURCE-REPO.ps1','tests\NEW-COMPLIANCE-REPO.ps1','tests\NEW-RELEASE-E2E-REPO.ps1',
 'DEV.ps1')
foreach($rel in $required){Check "Required $rel" {if(-not(Test-Path (Join-Path $root $rel))){throw 'missing'}}}
Check 'PowerShell syntax' {
 $files=Get-ChildItem $root -Recurse -File | Where-Object { $_.Extension -in @('.ps1','.psm1') }
 foreach($f in $files){
  $tokens=$null;$parseErrors=$null
  [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$parseErrors)|Out-Null
  if(@($parseErrors).Count){
   $details=@($parseErrors | ForEach-Object {
    $extent=$_.Extent
    $snippet=if($extent -and $extent.Text){$extent.Text.Replace("`r",' ').Replace("`n",' ')}else{''}
    "$($f.FullName):$($extent.StartLineNumber):$($extent.StartColumnNumber) $($_.Message) :: $snippet"
   })
   throw ($details -join '; ')
  }
 }
}
Check 'Version consistency' {
 $v=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim();if($v -ne '1.0.0-dev'){throw $v}
 $cat=Get-Content (Join-Path $root 'workflows\catalog.json') -Raw|ConvertFrom-Json;if($cat.version -ne $v){throw 'catalog mismatch'}
 foreach($cfg in @('config.yaml','config-agent.yaml','config-agent-fast.yaml')){if((Get-Content (Join-Path $root "config\$cfg") -Raw)-notmatch [regex]::Escape("version: $v")){throw "$cfg mismatch"}}
}
Check '22 slash workflows and modes' {
 $cat=Get-Content (Join-Path $root 'workflows\catalog.json') -Raw|ConvertFrom-Json
 if(@($cat.workflows).Count -ne 22){throw "count=$(@($cat.workflows).Count)"}
 foreach($i in $cat.workflows){if([string]::IsNullOrWhiteSpace([string]$i.mode)){throw "$($i.name) missing mode"};if(-not(Test-Path (Join-Path $root ('workflows\'+$i.file)))){throw "$($i.file) missing"}}
}
Check 'Test registry structural integrity' {
 $matrix=Get-Content (Join-Path $root 'tests\TEST-MATRIX.json') -Raw|ConvertFrom-Json
 $requiredFields=@('id','area','description','test','tier')
 $ids=@()
 foreach($c in @($matrix.contracts)){
  foreach($field in $requiredFields){if($null -eq $c.PSObject.Properties[$field]){throw "contract missing $field"}}
  $ids += [string]$c.id
  if(-not(Test-Path -LiteralPath (Join-Path $root ([string]$c.test)))){throw "missing test $($c.test)"}
 }
 if($ids.Count -ne @($ids|Select-Object -Unique).Count){throw 'duplicate test contract id'}
}
Check 'Regression scripts parse structurally' {
 $testFiles=Get-ChildItem (Join-Path $root 'tests') -Filter 'VERIFY-*.ps1' -File
 foreach($f in $testFiles){
  $tokens=$null;$parseErrors=$null
  [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$parseErrors)|Out-Null
  if(@($parseErrors).Count){throw "$($f.Name) parse error"}
 }
}
Check 'Release scenario assets' {
 $scenario=Get-Content (Join-Path $root 'tests\SCENARIO-MATRIX.json') -Raw | ConvertFrom-Json
 if(@($scenario.scenarios).Count -lt 8){throw 'scenario coverage too small'}
 foreach($rel in @('tests\RUN-STARTUP-SMOKE.ps1','tests\RUN-SHELL-E2E.ps1','QUALIFY-RELEASE.ps1')){if(-not(Test-Path (Join-Path $root $rel))){throw "missing scenario asset: $rel"}}
}
Check 'RUN-ALL release harness contract' {
 $t=Get-Content (Join-Path $root 'tests\RUN-ALL.ps1') -Raw
 foreach($n in @('Quick','Full','Release','NOT-QUALIFIED','results.json','report.md','RUN-REAL-PROJECT-SMOKE.ps1','RUN-LIVE-E2E.ps1','LiveE2E')){if($t -notmatch [regex]::Escape($n)){throw "RUN-ALL missing $n"}}
}
Check 'Slash prompts synchronized' {
 $cat=Get-Content (Join-Path $root 'workflows\catalog.json') -Raw|ConvertFrom-Json
 foreach($cfg in @('config.yaml','config-agent.yaml','config-agent-fast.yaml')){
  $text=Get-Content (Join-Path $root "config\$cfg") -Raw
  foreach($i in $cat.workflows){if($text -notmatch "(?m)^- name: $([regex]::Escape([string]$i.name))$"){throw "$cfg missing /$($i.name)"}}
 }
}
Check 'Distribution self-target guard' {$m=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw;if($m -notmatch 'is the Local Coding Agent distribution package'){throw 'guard missing'}}
Check 'Low-prompt safe permission profile' {
 $t=Get-Content (Join-Path $root 'config\permissions.yaml') -Raw
 if($t -notmatch '(?m)^- Bash\(\*\)$'){throw 'Bash automatic allow missing'}
 if($t -notmatch '(?m)^ask:\s*\[\]\s*$'){throw 'ask list is not empty'}
 if($t -notmatch 'Bash\(git push\*\)'){throw 'git push guard missing'}
 if($t -notmatch 'Bash\(cargo update\*\)'){throw 'dependency guard missing'}
}
Check 'No hardcoded user profile' {
 $scanFiles=@(Get-ChildItem $root -Recurse -File | Where-Object {
   $rel=$_.FullName.Substring($root.Length).TrimStart([char[]]@('\','/'))
   $rel -notmatch '^(?i)(?:logs|evidence|results|test-results|\.tmp|tmp)[\\/]'
 })
 $m=$scanFiles|Select-String -Pattern 'C:\\Users\\[^\\]+'
 if($m){
   $sample=@($m|Select-Object -First 5|ForEach-Object{"$($_.Path):$($_.LineNumber): $($_.Line.Trim())"})
   throw ("hardcoded user profile in distributable source: "+($sample -join ' | '))
 }
}
if($failed){Write-Host "Package verification FAILED: $failed" -ForegroundColor Red;exit 1}
Write-Host 'Package verification PASS' -ForegroundColor Cyan
