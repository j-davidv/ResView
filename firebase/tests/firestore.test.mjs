import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, deleteField, doc, getDoc, getDocs, limit,
  orderBy, query, serverTimestamp, setDoc, Timestamp, updateDoc, where,
} from 'firebase/firestore';

let env;
const selection = { examId: 'exam', sittingId: 'sitting', categoryId: 'category' };
const valid = () => ({ enabled: true, selection, token: 'test-token', lastActiveAtUtc: serverTimestamp() });
const publicPaths = ['exams/exam', 'sittings/sitting', 'publications/publication', 'resultVersions/version', 'monitor/status'];
const privatePaths = ['emailQueue/job', 'deliveryAttempts/attempt', 'workerState/cursor', 'validationReviews/review', 'unknown/document', 'monitor/private', 'exams/exam/private/record', 'pushPreferences/visitor/private/record'];

before(async () => {
  // Refuse the live project: all fixtures and simulated identities stay in the emulator.
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator is required');
  env = await initializeTestEnvironment({
    projectId: 'demo-resview-rules',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const path of [...publicPaths, ...privatePaths]) {
      await setDoc(doc(db, path), { title: 'Test only', examId: 'exam', start: Timestamp.now(), selection, publishedAtUtc: Timestamp.now(), current: true });
    }
  });
});
after(async () => { await env?.cleanup(); });

test('public metadata is readable without authentication; private paths are not', async () => {
  for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext('visitor').firestore()]) {
    for (const path of publicPaths) await assertSucceeds(getDoc(doc(db, path)));
    for (const path of privatePaths) await assertFails(getDoc(doc(db, path)));
    await assertFails(getDocs(collection(db, 'monitor')));
  }
});

test('the exact app query shapes are allowed', async () => {
  const db = env.unauthenticatedContext().firestore();
  const filters = Object.entries(selection).map(([key, value]) => where(`selection.${key}`, '==', value));
  for (const q of [
    query(collection(db, 'exams'), orderBy('title'), limit(250)),
    query(collection(db, 'sittings'), where('examId', '==', 'exam'), orderBy('start'), limit(250)),
    query(collection(db, 'publications'), ...filters, orderBy('publishedAtUtc', 'desc'), limit(50)),
    query(collection(db, 'resultVersions'), ...filters, where('current', '==', true), limit(1)),
  ]) await assertSucceeds(getDocs(q));
});

test('all clients are denied public and worker writes', async () => {
  for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext('writer').firestore()]) {
    for (const path of [...publicPaths, ...privatePaths]) {
      await assertFails(setDoc(doc(db, path), { injected: true }));
      await assertFails(updateDoc(doc(db, path), { injected: true }));
      await assertFails(deleteDoc(doc(db, path)));
    }
  }
});

test('owner can register, restore, rotate token, change selection and delete', async () => {
  const ref = doc(env.authenticatedContext('owner').firestore(), 'pushPreferences/owner');
  await assertSucceeds(setDoc(ref, valid()));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(updateDoc(ref, { token: 'rotated-token', lastActiveAtUtc: serverTimestamp() }));
  await assertSucceeds(setDoc(ref, { ...valid(), selection: { ...selection, categoryId: 'another-category' } }));
  await assertSucceeds(deleteDoc(ref));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(deleteDoc(ref));
});

test('another user and an unauthenticated client cannot access owner preferences', async () => {
  await setDoc(doc(env.authenticatedContext('alice').firestore(), 'pushPreferences/alice'), valid());
  for (const db of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    const ref = doc(db, 'pushPreferences/alice');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, valid()));
    await assertFails(updateDoc(ref, { token: 'stolen', lastActiveAtUtc: serverTimestamp() }));
    await assertFails(deleteDoc(ref));
    await assertFails(getDocs(collection(db, 'pushPreferences')));
  }
});

test('invalid registration and update payloads are rejected', async () => {
  const ref = doc(env.authenticatedContext('validation').firestore(), 'pushPreferences/validation');
  const invalid = [
    { name: 'private name' }, { email: 'private@example.invalid' }, { outcome: 'private' }, { role: 'admin' },
    { enabled: false }, { enabled: 'true' }, { token: '' }, { token: 42 }, { token: 'x'.repeat(4097) },
    { selection: null }, { selection: {} }, { selection: { ...selection, email: 'private@example.invalid' } },
    ...Object.keys(selection).flatMap(key => [
      { selection: { ...selection, [key]: '' } },
      { selection: { ...selection, [key]: 42 } },
      { selection: { ...selection, [key]: 'x'.repeat(257) } },
      { selection: { ...selection, [key]: 'invalid/path' } },
      { selection: { ...selection, [key]: ' ' } },
      { selection: Object.fromEntries(Object.entries(selection).filter(([field]) => field !== key)) },
    ]),
    { lastActiveAtUtc: Timestamp.fromMillis(0) }, { lastActiveAtUtc: 'now' },
    { lastActiveAtUtc: Timestamp.fromMillis(Date.now() + 86400000) },
  ];
  for (const patch of invalid) {
    await assertFails(setDoc(ref, { ...valid(), ...patch }));
    await setDoc(ref, valid());
    await assertFails(updateDoc(ref, { ...patch, ...(Object.hasOwn(patch, 'lastActiveAtUtc') ? {} : { lastActiveAtUtc: serverTimestamp() }) }));
    await deleteDoc(ref);
  }
  for (const key of Object.keys(valid())) {
    const payload = valid();
    delete payload[key];
    await assertFails(setDoc(ref, payload));
    await setDoc(ref, valid());
    await assertFails(updateDoc(ref, { [key]: deleteField(), ...(key === 'lastActiveAtUtc' ? {} : { lastActiveAtUtc: serverTimestamp() }) }));
    await deleteDoc(ref);
  }
});
