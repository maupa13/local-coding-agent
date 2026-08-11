const test = require('node:test');
const assert = require('node:assert/strict');
const { SessionStore } = require(process.env.EVAL_PROJECT + '/src/session-store');

test('rejects all invalid inputs without mutating state', () => {
  let now = 10;
  const store = new SessionStore(() => now);
  for (const args of [['', 'x', 1], ['id', '', 1], ['id', 'x', 0], ['id', 'x', -1]]) {
    assert.throws(() => store.save(...args), { name: 'TypeError' });
  }
  assert.equal(store.load('id'), null);
});

test('expires exactly at boundary and deletes expired entry', () => {
  let now = 100;
  const store = new SessionStore(() => now);
  store.save('a', 'token', 5);
  now = 105;
  assert.equal(store.load('a'), null);
  assert.equal(store.clear('a'), false);
});

test('selective clear and bulk expiry preserve live sessions', () => {
  let now = 100;
  const store = new SessionStore(() => now);
  store.save('expired-1', 'a', 1);
  store.save('expired-2', 'b', 2);
  store.save('live', 'c', 100);
  now = 102;
  assert.equal(store.clearExpired(), 2);
  assert.equal(store.load('live'), 'c');
  assert.equal(store.clear('live'), true);
  assert.equal(store.clear('live'), false);
});

