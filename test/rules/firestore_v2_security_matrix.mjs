import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const hostPort = process.env.FIRESTORE_EMULATOR_HOST ? process.env.FIRESTORE_EMULATOR_HOST.split(':') : ['127.0.0.1', '8088'];
const host = hostPort[0];
const port = parseInt(hostPort[1], 10);

console.log(`[TEST RUNNER] Connecting to Firestore Emulator at ${host}:${port}...`);

const rules = readFileSync('firestore/firestore_v2.rules', 'utf8');

const testEnv = await initializeTestEnvironment({
  projectId: 'recovery-for-all-c2ee8',
  firestore: {
    rules,
    host,
    port
  }
});

let passed = 0;
let failed = 0;

async function runTest(name, fn) {
  try {
    await fn();
    console.log(`  ✓ PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✗ FAIL: ${name}`);
    console.error(`    Error: ${err.message}`);
    failed++;
  }
}

console.log('\n--- EXECUTING ACTUAL EMULATOR SECURITY TEST MATRIX ---');

// 1. Owner can create a valid post
await runTest('Owner can create a valid post', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const postRef = doc(alice.firestore(), 'circle_v2/post_1');
  await assertSucceeds(setDoc(postRef, {
    ownerUid: 'alice_123',
    authorAlias: 'Alice In Recovery',
    body: 'One day at a time. Clean today.',
    createdAt: Date.now(),
    status: 'visible',
    kind: 'text',
    needsSupport: false
  }));
});

// 2. Forged owner UID is denied
await runTest('Forged owner UID is denied', async () => {
  const mallory = testEnv.authenticatedContext('mallory_999');
  const postRef = doc(mallory.firestore(), 'circle_v2/post_forged');
  await assertFails(setDoc(postRef, {
    ownerUid: 'alice_123', // Forging alice's uid
    authorAlias: 'Mallory Impersonator',
    body: 'Forged post body',
    createdAt: Date.now(),
    status: 'visible'
  }));
});

// 3. Unauthenticated post creation is denied
await runTest('Unauthenticated post creation is denied', async () => {
  const unauth = testEnv.unauthenticatedContext();
  const postRef = doc(unauth.firestore(), 'circle_v2/post_unauth');
  await assertFails(setDoc(postRef, {
    ownerUid: 'anon',
    authorAlias: 'Anon',
    body: 'Anonymous body',
    createdAt: Date.now(),
    status: 'visible'
  }));
});

// 4. Invalid post payloads are denied (body > 480 chars, invalid status, forbidden fields)
await runTest('Invalid post payload (body > 480 chars) is denied', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const postRef = doc(alice.firestore(), 'circle_v2/post_too_long');
  await assertFails(setDoc(postRef, {
    ownerUid: 'alice_123',
    authorAlias: 'Alice',
    body: 'A'.repeat(481),
    createdAt: Date.now(),
    status: 'visible'
  }));
});

await runTest('Invalid post payload (status != visible) is denied', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const postRef = doc(alice.firestore(), 'circle_v2/post_hidden');
  await assertFails(setDoc(postRef, {
    ownerUid: 'alice_123',
    authorAlias: 'Alice',
    body: 'Testing status injection',
    createdAt: Date.now(),
    status: 'approved' // Bypassing moderation queue
  }));
});

await runTest('Invalid post payload (unauthorized extra fields) is denied', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const postRef = doc(alice.firestore(), 'circle_v2/post_extra_fields');
  await assertFails(setDoc(postRef, {
    ownerUid: 'alice_123',
    authorAlias: 'Alice',
    body: 'Testing unauthorized field injection',
    createdAt: Date.now(),
    status: 'visible',
    isAdmin: true // Forbidden field
  }));
});

// 5. Non-owner update/delete is denied
await runTest('Non-owner update is denied', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const postRef = doc(bob.firestore(), 'circle_v2/post_1');
  await assertFails(updateDoc(postRef, {
    body: 'Tampered by Bob'
  }));
});

await runTest('Owner post update is denied (posts are immutable)', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const postRef = doc(alice.firestore(), 'circle_v2/post_1');
  await assertFails(updateDoc(postRef, {
    body: 'Alice attempting edit'
  }));
});

await runTest('Non-owner deletion is denied', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const postRef = doc(bob.firestore(), 'circle_v2/post_1');
  await assertFails(deleteDoc(postRef));
});

// 6. Owner deletion works
await runTest('Owner deletion works', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const postRef = doc(alice.firestore(), 'circle_v2/post_1');
  await assertSucceeds(deleteDoc(postRef));
});

// 7. Reaction spoofing and duplicate/inflated reactions are denied
// First recreate post_target by alice for reaction testing
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const postRef = doc(ctx.firestore(), 'circle_v2/post_reaction_target');
  await setDoc(postRef, {
    ownerUid: 'alice_123',
    authorAlias: 'Alice',
    body: 'Target for reactions',
    createdAt: Date.now(),
    status: 'visible'
  });
});

await runTest('Authenticated user can add valid reaction with matching docId and kind', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reactionRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reactions/bob_456_strength');
  await assertSucceeds(setDoc(reactionRef, {
    actorUid: 'bob_456',
    kind: 'strength',
    createdAt: Date.now()
  }));
});

await runTest('Reaction spoofing (actorUid != request.auth.uid) is denied', async () => {
  const mallory = testEnv.authenticatedContext('mallory_999');
  const reactionRef = doc(mallory.firestore(), 'circle_v2/post_reaction_target/reactions/alice_123_proud');
  await assertFails(setDoc(reactionRef, {
    actorUid: 'alice_123',
    kind: 'proud',
    createdAt: Date.now()
  }));
});

await runTest('Reaction spoofing (docId does not match actorUid_kind) is denied', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reactionRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reactions/random_doc_id');
  await assertFails(setDoc(reactionRef, {
    actorUid: 'bob_456',
    kind: 'strength',
    createdAt: Date.now()
  }));
});

await runTest('Disallowed reaction kind (e.g. "dislike" or "laugh") is denied', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reactionRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reactions/bob_456_dislike');
  await assertFails(setDoc(reactionRef, {
    actorUid: 'bob_456',
    kind: 'dislike',
    createdAt: Date.now()
  }));
});

await runTest('Reaction modification/counter inflation is denied', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reactionRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reactions/bob_456_strength');
  await assertFails(updateDoc(reactionRef, {
    count: 100 // Counter inflation attempt
  }));
});

await runTest('User can delete their own reaction', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reactionRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reactions/bob_456_strength');
  await assertSucceeds(deleteDoc(reactionRef));
});

// 8. Unauthorized report reads are denied, report filing works with bounded validation
await runTest('Authenticated user can file a valid report', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reportRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reports/bob_456');
  await assertSucceeds(setDoc(reportRef, {
    reporterUid: 'bob_456',
    reasonCode: 'harassment',
    createdAt: Date.now(),
    notes: 'Inappropriate content.'
  }));
});

await runTest('Unauthorized report read by reporter is denied (reports are private)', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reportRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reports/bob_456');
  await assertFails(getDoc(reportRef));
});

await runTest('Unauthorized report read by post author is denied', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const reportRef = doc(alice.firestore(), 'circle_v2/post_reaction_target/reports/bob_456');
  await assertFails(getDoc(reportRef));
});

await runTest('Report modification or deletion by client is denied', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const reportRef = doc(bob.firestore(), 'circle_v2/post_reaction_target/reports/bob_456');
  await assertFails(deleteDoc(reportRef));
});

// 9. Legacy v1 content remains readable but immutable
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const v1Ref = doc(ctx.firestore(), 'community_feeds/v1_archived_post');
  await setDoc(v1Ref, {
    authorAlias: 'LegacyUser',
    body: 'Historic feed item from 2026-08',
    status: 'visible',
    createdAt: 1724500000000
  });
});

await runTest('Legacy v1 feed item is readable by authenticated user', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const v1Ref = doc(alice.firestore(), 'community_feeds/v1_archived_post');
  await assertSucceeds(getDoc(v1Ref));
});

await runTest('Legacy v1 feed creation is denied', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const v1Ref = doc(alice.firestore(), 'community_feeds/v1_new_attempt');
  await assertFails(setDoc(v1Ref, {
    authorAlias: 'Alice',
    body: 'Attempting v1 create',
    createdAt: Date.now(),
    status: 'visible'
  }));
});

await runTest('Legacy v1 feed update is denied', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const v1Ref = doc(alice.firestore(), 'community_feeds/v1_archived_post');
  await assertFails(updateDoc(v1Ref, {
    body: 'Modified legacy post'
  }));
});

await runTest('Legacy v1 feed deletion is denied', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const v1Ref = doc(alice.firestore(), 'community_feeds/v1_archived_post');
  await assertFails(deleteDoc(v1Ref));
});

// 10. Existing care-alert and sponsor-bundle permission boundaries remain intact
await runTest('Care alert creation by caller for their own path succeeds', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const alertRef = doc(alice.firestore(), 'care_alerts/alice_123');
  await assertSucceeds(setDoc(alertRef, {
    createdAt: Date.now()
  }));
});

await runTest('Care alert creation for someone else is denied', async () => {
  const mallory = testEnv.authenticatedContext('mallory_999');
  const alertRef = doc(mallory.firestore(), 'care_alerts/alice_123');
  await assertFails(setDoc(alertRef, {
    createdAt: Date.now()
  }));
});

await runTest('Care alert read is denied (distress signal privacy)', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const alertRef = doc(alice.firestore(), 'care_alerts/alice_123');
  await assertFails(getDoc(alertRef));
});

await runTest('Sponsor bundle creation by owner succeeds', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const bundleRef = doc(alice.firestore(), 'sponsor_bundles/alice_123');
  await assertSucceeds(setDoc(bundleRef, {
    ownerUid: 'alice_123',
    status: 'pending',
    bundle: 'encrypted_payload_hex',
    sponsorCode: 'SPONSOR-99'
  }));
});

await runTest('Sponsor bundle read by owner succeeds', async () => {
  const alice = testEnv.authenticatedContext('alice_123');
  const bundleRef = doc(alice.firestore(), 'sponsor_bundles/alice_123');
  await assertSucceeds(getDoc(bundleRef));
});

await runTest('Sponsor bundle read by unauthorized peer is denied', async () => {
  const bob = testEnv.authenticatedContext('bob_456');
  const bundleRef = doc(bob.firestore(), 'sponsor_bundles/alice_123');
  await assertFails(getDoc(bundleRef));
});

await testEnv.cleanup();

console.log(`\n[EMULATOR MATRIX SUMMARY] Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`);

if (failed > 0) {
  process.exit(1);
} else {
  console.log('ALL SECURITY EMULATOR TESTS PASSED WITH ZERO FAILURES.\n');
  process.exit(0);
}
