[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'

try{
  Import-Module $modulePath -Force -DisableNameChecking

  $task='Проанализируй docs и построй COMPLIANCE MATRIX для каждого REQ с evidence.'
  $valid=@'
## COMPLIANCE MATRIX
| REQ | requirement | status | implementation evidence | test/verification evidence | gap |
|---|---|---|---|---|---|
| REQ-01 | save | PASS | src/session-store.js | tests/session-store.test.js | NONE |
| REQ-02 | load | PASS | src/session-store.js | tests/session-store.test.js | NONE |
| REQ-03 | clear | FAIL | src/session-store.js | NOT VERIFIED | broken |

FINAL RESULT: FAIL
WORKFLOW: analysis
SUMMARY
REQ-03 fails.
'@

  if(-not(Test-LocalCodingAgentComplianceResult -WorkflowName 'analysis' -TaskText $task -Text $valid)){
    throw '[FAIL] canonical matrix-before-final response was rejected'
  }
  Write-Host '[PASS] canonical matrix-before-final response accepted' -ForegroundColor Green

  $invalid=@'
FINAL RESULT: FAIL
WORKFLOW: analysis
SUMMARY
No compliance matrix was produced.
'@
  if(Test-LocalCodingAgentComplianceResult -WorkflowName 'analysis' -TaskText $task -Text $invalid){
    throw '[FAIL] compliance response without matrix was accepted'
  }
  Write-Host '[PASS] response without matrix rejected' -ForegroundColor Green
  Write-Host 'Compliance matrix layout behavioral regression PASS' -ForegroundColor Cyan
}finally{
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
}
