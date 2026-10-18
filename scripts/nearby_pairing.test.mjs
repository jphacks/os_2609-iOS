// npm install --prefix /tmp/os2609-pairing-tests @electric-sql/pglite
// PGLITE_MODULE=file:///tmp/os2609-pairing-tests/node_modules/@electric-sql/pglite/dist/index.js node --test scripts/nearby_pairing.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const { PGlite } = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const migration = await readFile(new URL('../supabase/migrations/20261018_nearby_battle_consent.sql', import.meta.url), 'utf8');
const ids = [1, 2, 3].map(n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`);
async function fixture(run) {
  const db = new PGlite();
  try {
    await db.exec('create role anon; create role authenticated;');
    await db.exec(migration);
    const call = async (session, action, peer = null, token = null) =>
      (await db.query('select * from nearby_pair($1::uuid, $2::text, $3::uuid, $4::uuid)', [session, action, peer, token])).rows[0];
    for (const id of ids) await call(id, 'poll');
    await run(db, call);
  } finally { await db.close(); }
}

test('crossed offers reserve a single pair and return the same token to both participants', async () => {
  // 三角形の書き込みがどの順序でも、端末が複数ペアに所属しない。
  for (const order of [[0,1,2], [0,2,1], [1,0,2], [1,2,0], [2,0,1], [2,1,0]]) {
    await fixture(async (db, call) => {
      for (const i of order) await call(ids[i], 'offer', ids[(i + 1) % 3]);
      const pairs = (await db.query("select * from nearby_pairs where status = 'pending'")).rows;
      assert.equal(pairs.length, 1);
      const pair = pairs[0];
      assert.equal((await call(pair.session1, 'poll')).id, pair.id);
      assert.equal((await call(pair.session2, 'poll')).id, pair.id);
    });
  }
});

test('only both consents make a pair ready, and repeated consent is safe', async () => fixture(async (db, call) => {
  const pair = await call(ids[0], 'offer', ids[1]);
  assert.equal((await call(ids[0], 'accept', null, pair.id)).status, 'pending');
  assert.equal((await call(ids[0], 'accept', null, pair.id)).status, 'pending');
  assert.equal((await call(ids[1], 'accept', null, pair.id)).status, 'ready');
  assert.equal((await call(ids[0], 'poll', null, pair.id)).status, 'ready');
  // 対戦画面への遷移で受付を停止しても、相手は ready を取得できる。
  await call(ids[0], 'stop');
  assert.equal((await call(ids[1], 'poll', null, pair.id)).status, 'ready');
}));

test('decline reaches the participant who already accepted', async () => fixture(async (db, call) => {
  const pair = await call(ids[0], 'offer', ids[1]);
  await call(ids[0], 'accept', null, pair.id);
  await call(ids[1], 'stop');
  assert.equal((await call(ids[0], 'poll', null, pair.id)).status, 'cancelled');
  assert.equal((await call(ids[0], 'accept', null, pair.id)).status, 'cancelled');
}));

test('a timed out pair cannot start a battle', async () => fixture(async (db, call) => {
  const pair = await call(ids[0], 'offer', ids[1]);
  await db.query("update nearby_pairs set expires_at = now() - interval '1 second' where id = $1", [pair.id]);
  assert.equal((await call(ids[0], 'accept', null, pair.id)).status, 'expired');
  assert.equal((await call(ids[1], 'poll', null, pair.id)).status, 'expired');
}));

test('late offers cannot restore a stopped reception or reserve an unavailable peer', async () => fixture(async (db, call) => {
  await call(ids[0], 'stop');
  assert.equal(await call(ids[0], 'offer', ids[1]), undefined);
  assert.equal(await call(ids[1], 'offer', ids[0]), undefined);
  assert.equal(await call(ids[0], 'poll'), undefined);
  await db.query("update nearby_receivers set last_seen_at = now() - interval '6 seconds' where session_id = $1", [ids[2]]);
  assert.equal(await call(ids[1], 'offer', ids[2]), undefined);
  assert.equal((await db.query('select count(*)::int as count from nearby_pairs')).rows[0].count, 0);
}));

test('a third participant cannot accept or read a reserved token', async () => fixture(async (db, call) => {
  const pair = await call(ids[0], 'offer', ids[1]);
  assert.equal(await call(ids[2], 'accept', null, pair.id), undefined);
  const stored = (await db.query('select * from nearby_pairs where id = $1', [pair.id])).rows[0];
  assert.equal(stored.accepted1, false);
  assert.equal(stored.accepted2, false);
  assert.equal(await call(ids[0], 'offer', ids[2], ids[2]), undefined);
  assert.equal((await db.query('select count(*)::int as count from nearby_pairs')).rows[0].count, 1);
}));
