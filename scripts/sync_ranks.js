#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require('fs');
const admin = require('firebase-admin');

const USERS_COLLECTION = 'users';
const SCHOOLS_COLLECTION = 'schools';
const BATCH_LIMIT = 400;

function toInt(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  return 0;
}

function compareByScoreThenId(a, b, scoreField) {
  const scoreDiff = toInt(b[scoreField]) - toInt(a[scoreField]);
  if (scoreDiff != 0) return scoreDiff;
  return a.id.localeCompare(b.id);
}

function initFirebase() {
  if (admin.apps.length > 0) return;

  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

async function commitBatchIfNeeded(db, state, force = false) {
  if (!force && state.count < BATCH_LIMIT) return;
  if (state.count === 0) return;
  await state.batch.commit();
  state.batch = db.batch();
  state.count = 0;
}

async function syncUserRanks(db) {
  const snapshot = await db.collection(USERS_COLLECTION).get();
  const users = snapshot.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      id: doc.id,
      ref: doc.ref,
      schoolId: (data.schoolId || '').toString(),
      score_total_personal: toInt(data.score_total_personal),
    };
  });

  if (users.length === 0) {
    console.log('[syncUserRanks] No users found.');
    return { userCount: 0 };
  }

  users.sort((a, b) => compareByScoreThenId(a, b, 'score_total_personal'));
  const overallRankByUserId = new Map();
  for (let i = 0; i < users.length; i++) {
    overallRankByUserId.set(users[i].id, i + 1);
  }

  const usersBySchool = new Map();
  for (const user of users) {
    if (!user.schoolId) continue;
    if (!usersBySchool.has(user.schoolId)) {
      usersBySchool.set(user.schoolId, []);
    }
    usersBySchool.get(user.schoolId).push(user);
  }

  const schoolRankByUserId = new Map();
  for (const schoolUsers of usersBySchool.values()) {
    schoolUsers.sort((a, b) => compareByScoreThenId(a, b, 'score_total_personal'));
    for (let i = 0; i < schoolUsers.length; i++) {
      schoolRankByUserId.set(schoolUsers[i].id, i + 1);
    }
  }

  const state = { batch: db.batch(), count: 0 };
  const rankCalculatedAt = admin.firestore.FieldValue.serverTimestamp();
  for (const user of users) {
    const schoolRank = schoolRankByUserId.has(user.id)
      ? schoolRankByUserId.get(user.id)
      : null;
    state.batch.update(user.ref, {
      overallRank: overallRankByUserId.get(user.id),
      schoolRank,
      rankCalculatedAt,
    });
    state.count++;
    await commitBatchIfNeeded(db, state);
  }
  await commitBatchIfNeeded(db, state, true);

  console.log(`[syncUserRanks] Updated ${users.length} users.`);
  return { userCount: users.length };
}

async function syncSchoolRanks(db) {
  const snapshot = await db.collection(SCHOOLS_COLLECTION).get();
  const schools = snapshot.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      id: doc.id,
      ref: doc.ref,
      score_total: toInt(data.score_total),
    };
  });

  if (schools.length === 0) {
    console.log('[syncSchoolRanks] No schools found.');
    return { schoolCount: 0 };
  }

  schools.sort((a, b) => compareByScoreThenId(a, b, 'score_total'));
  const state = { batch: db.batch(), count: 0 };
  const rankCalculatedAt = admin.firestore.FieldValue.serverTimestamp();

  for (let i = 0; i < schools.length; i++) {
    state.batch.update(schools[i].ref, {
      overallRank: i + 1,
      rankCalculatedAt,
    });
    state.count++;
    await commitBatchIfNeeded(db, state);
  }
  await commitBatchIfNeeded(db, state, true);

  console.log(`[syncSchoolRanks] Updated ${schools.length} schools.`);
  return { schoolCount: schools.length };
}

async function main() {
  initFirebase();
  const db = admin.firestore();

  console.log('[sync_ranks] Starting rank synchronization...');
  const userResult = await syncUserRanks(db);
  const schoolResult = await syncSchoolRanks(db);
  console.log('[sync_ranks] Completed.');
  console.log(
    `[sync_ranks] Summary: users=${userResult.userCount}, schools=${schoolResult.schoolCount}`,
  );
}

main().catch((error) => {
  console.error('[sync_ranks] Failed:', error);
  process.exit(1);
});
