const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {runInNewContext} = require('node:vm');

function page(responses = []) {
  const ids = ['login', 'confirmation', 'status', 'confirm', 'delete',
    'cancel', 'account', 'sign-in', 'email', 'password'];
  const elements = Object.fromEntries(ids.map((id) => [id, {
    value: '', checked: false, disabled: false, hidden: id === 'confirmation',
    textContent: '', listeners: {},
    addEventListener(event, handler) { this.listeners[event] = handler; },
    focus() {},
    reset() { elements.confirm.checked = false; },
  }]));
  const calls = [];
  const html = readFileSync(join(__dirname,
    '../../public_landing/home/profile/delete-account/index.html'), 'utf8');
  runInNewContext(html.match(/<script>([\s\S]*?)<\/script>/)[1], {
    document: {getElementById: (id) => elements[id]},
    fetch: async (url, options) => {
      calls.push({url, options});
      const response = responses.shift();
      if (!response) throw new Error('Unexpected request');
      return {ok: response.ok, json: async () => response.body};
    },
  });
  return {
    elements, calls,
    fire: async (id, event) => elements[id].listeners[event]({preventDefault() {}}),
  };
}

test('opening the external page never sends a deletion request', () => {
  assert.equal(page().calls.length, 0);
});

test('deletion requires both authentication and explicit confirmation', async () => {
  const view = page();
  view.elements.confirm.checked = true;
  await view.fire('confirmation', 'submit');
  assert.equal(view.calls.length, 0);
});

test('login only reveals confirmation; submit sends the authenticated request', async () => {
  const view = page([
    {ok: true, body: {idToken: 'verified-token', email: 'test@example.com'}},
    {ok: true, body: {result: {deleted: true}}},
  ]);
  view.elements.email.value = 'test@example.com';
  view.elements.password.value = 'example-password';
  await view.fire('login', 'submit');
  assert.equal(view.calls.length, 1);
  assert.equal(view.elements.password.value, '');
  assert.equal(view.elements.confirmation.hidden, false);
  await view.fire('confirmation', 'submit');
  assert.equal(view.calls.length, 1);
  view.elements.confirm.checked = true;
  await view.fire('confirmation', 'submit');
  assert.equal(view.calls.length, 2);
  assert.equal(view.calls[1].options.headers.Authorization, 'Bearer verified-token');
  assert.deepEqual(JSON.parse(view.calls[1].options.body), {data: {confirm: true}});
  assert.match(view.elements.status.textContent, /se ha cerrado tu cuenta/);
});

test('cancelling discards the authenticated token and preserves the account', async () => {
  const view = page([{ok: true, body: {idToken: 'verified-token'}}]);
  await view.fire('login', 'submit');
  await view.fire('cancel', 'click');
  view.elements.confirm.checked = true;
  await view.fire('confirmation', 'submit');
  assert.equal(view.calls.length, 1);
  assert.equal(view.elements.login.hidden, false);
});

test('expired authentication requires a fresh sign-in', async () => {
  const view = page([
    {ok: true, body: {idToken: 'expired-token'}},
    {ok: false, body: {error: {status: 'UNAUTHENTICATED'}}},
  ]);
  await view.fire('login', 'submit');
  view.elements.confirm.checked = true;
  await view.fire('confirmation', 'submit');
  assert.equal(view.elements.login.hidden, false);
  assert.match(view.elements.status.textContent, /ha caducado/);
});
