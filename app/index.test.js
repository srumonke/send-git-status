const test = require('node:test');
const assert = require('node:assert');
const { greet } = require('./index');

test('greets a name', () => {
  assert.strictEqual(greet('cint'), 'hello, cint');
});

test('rejects an empty name', () => {
  assert.throws(() => greet(''), /name is required/);
});
