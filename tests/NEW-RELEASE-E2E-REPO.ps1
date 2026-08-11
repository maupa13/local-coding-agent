[CmdletBinding()]
param([string]$Path='C:\AI\local-coding-agent-release-e2e')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $Path){Remove-Item -LiteralPath $Path -Recurse -Force}
New-Item -ItemType Directory -Force -Path (Join-Path $Path 'docs'),(Join-Path $Path 'src'),(Join-Path $Path 'tests')|Out-Null
@'
# Session store requirements

REQ-01: `SessionStore.save(token)` must persist the supplied token.
REQ-02: `SessionStore.load()` must return the persisted token.
REQ-03: `SessionStore.clear()` must remove the persisted token so that `load()` returns `null`.
REQ-04: save/load/clear behavior must have automated regression tests.
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\requirements.md')
@'
class SessionStore {
  constructor() {
    this.token = null;
  }

  save(token) {
    this.token = token;
  }

  load() {
    return this.token;
  }

  clear() {
    // Intentional release fixture defect: clear is a no-op.
    return this.token;
  }
}

module.exports = { SessionStore };
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'src\session-store.js')
@'
const test = require('node:test');
const assert = require('node:assert/strict');
const { SessionStore } = require('../src/session-store');

test('save/load roundtrip', () => {
  const store = new SessionStore();
  store.save('abc');
  assert.equal(store.load(), 'abc');
});
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\session-store.test.js')
@'
{
  "name": "local-coding-agent-release-e2e",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "test": "node --test"
  }
}
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'package.json')
$oldEap=$ErrorActionPreference
$ErrorActionPreference='Continue'
try{
  & git -C $Path init 2>$null | Out-Null
  if($LASTEXITCODE -ne 0){throw 'release fixture git init failed'}
  & git -C $Path config user.email 'fixture@example.invalid' 2>$null | Out-Null
  if($LASTEXITCODE -ne 0){throw 'release fixture git config email failed'}
  & git -C $Path config user.name 'Local Coding Agent Release Fixture' 2>$null | Out-Null
  if($LASTEXITCODE -ne 0){throw 'release fixture git config name failed'}
  & git -C $Path add . 2>$null | Out-Null
  if($LASTEXITCODE -ne 0){throw 'release fixture git add failed'}
  & git -C $Path commit -m 'release e2e baseline' 2>$null | Out-Null
  if($LASTEXITCODE -ne 0){throw 'release fixture git commit failed'}
}finally{$ErrorActionPreference=$oldEap}

Write-Host "[PASS] Release E2E fixture: $Path" -ForegroundColor Green
