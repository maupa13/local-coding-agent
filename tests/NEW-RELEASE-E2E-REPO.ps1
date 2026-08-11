[CmdletBinding()]
param([string]$Path='C:\AI\local-coding-agent-release-e2e')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $Path){Remove-Item -LiteralPath $Path -Recurse -Force}
New-Item -ItemType Directory -Force -Path (Join-Path $Path 'docs'),(Join-Path $Path 'src'),(Join-Path $Path 'tests')|Out-Null
@'
# Session service specification

REQ-01: `SessionStore.save(id, token, ttlMs)` stores independent sessions and throws `TypeError` for blank ids/tokens or non-positive TTL.
REQ-02: `SessionStore.load(id)` returns the token before expiry and returns `null` while removing the session at/after expiry.
REQ-03: `SessionStore.clear(id)` removes only the selected session and returns whether it existed.
REQ-04: `SessionStore.clearExpired()` removes every expired session, preserves live sessions, and returns the removal count.
REQ-05: `TokenService.issue(userId, ttlMs)` creates `sess_<sequence>` ids and delegates storage; invalid input must propagate.
REQ-06: `TokenService.revoke(sessionId)` delegates to clear and returns its boolean result.
REQ-07: Public CommonJS exports remain `{ SessionStore }` and `{ TokenService }`.
REQ-08: Automated tests cover validation, session isolation, expiry boundary, selective revoke, and bulk expiry cleanup.
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\requirements.md')
@'
class SessionStore {
  constructor(now = () => Date.now()) {
    this.now = now;
    this.sessions = new Map();
  }

  save(id, token, ttlMs) {
    // BUG: no validation and expiry is ignored.
    this.sessions.set(id, { token });
  }

  load(id) {
    return this.sessions.get(id)?.token ?? null;
  }

  clear(id) {
    // BUG: clears every session and has no boolean contract.
    this.sessions.clear();
  }

  clearExpired() {
    // BUG: expiry is not implemented.
    return 0;
  }
}

module.exports = { SessionStore };
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'src\session-store.js')
@'
class TokenService {
  constructor(store) {
    this.store = store;
    this.sequence = 0;
  }

  issue(userId, ttlMs) {
    // BUG: collisions and no persistence delegation.
    return { sessionId: 'session', token: `token:${userId}` };
  }

  revoke(sessionId) {
    this.store.clear(sessionId);
  }
}

module.exports = { TokenService };
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'src\token-service.js')
@'
const test = require('node:test');
const assert = require('node:assert/strict');
const { SessionStore } = require('../src/session-store');

test('stores two independent sessions', () => {
  let now = 1000;
  const store = new SessionStore(() => now);
  store.save('a', 'alpha', 100);
  store.save('b', 'beta', 200);
  assert.equal(store.load('a'), 'alpha');
  assert.equal(store.load('b'), 'beta');
});
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\session-store.test.js')
@'
const test = require('node:test');
const assert = require('node:assert/strict');
const { SessionStore } = require('../src/session-store');
const { TokenService } = require('../src/token-service');

test('issues a token for a user', () => {
  const store = new SessionStore(() => 1000);
  const service = new TokenService(store);
  const issued = service.issue('user-1', 500);
  assert.match(issued.sessionId, /^sess_\d+$/);
  assert.equal(store.load(issued.sessionId), issued.token);
});
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\token-service.test.js')
@'
{
  "name": "local-coding-agent-release-e2e",
  "version": "1.0.0",
  "private": true,
  "scripts": { "test": "node --test" }
}
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'package.json')
$oldEap=$ErrorActionPreference;$ErrorActionPreference='Continue'
try{
  & git -C $Path init 2>$null|Out-Null;if($LASTEXITCODE -ne 0){throw 'release fixture git init failed'}
  & git -C $Path config user.email 'fixture@example.invalid' 2>$null|Out-Null
  & git -C $Path config user.name 'Local Coding Agent Release Fixture' 2>$null|Out-Null
  & git -C $Path add . 2>$null|Out-Null
  & git -C $Path commit -m 'release e2e baseline' 2>$null|Out-Null;if($LASTEXITCODE -ne 0){throw 'release fixture git commit failed'}
}finally{$ErrorActionPreference=$oldEap}
Write-Host "[PASS] Release E2E fixture: $Path" -ForegroundColor Green
