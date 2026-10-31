const {test} = require('node:test');
const assert = require('node:assert/strict');
const {deleteMyAccount} = require('../lib/delete_account');

test('rejects unauthenticated deletion even when a target UID is supplied', async () => {
  await assert.rejects(
    deleteMyAccount.run({confirm: true, uid: 'someone-else'}, {}),
    {code: 'unauthenticated'}
  );
});

test('requires explicit confirmation before accessing account data', async () => {
  const auth = {uid: 'test-user', token: {auth_time: Date.now() / 1000}};
  for (const data of [undefined, {}, {confirm: false}, {confirm: 'true'}]) {
    await assert.rejects(deleteMyAccount.run(data, {auth}), {
      code: 'failed-precondition',
    });
  }
});

test('rejects expired, missing and malformed identity verification', async () => {
  for (const authTime of [undefined, 'invalid', 0, Date.now() / 1000 - 301]) {
    await assert.rejects(
      deleteMyAccount.run({confirm: true}, {
        auth: {uid: 'test-user', token: {auth_time: authTime}},
      }),
      {code: 'unauthenticated'}
    );
  }
});
