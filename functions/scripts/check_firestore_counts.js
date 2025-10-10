#!/usr/bin/env node

/**
 * Quick helper script to check Firestore collection sizes and sample IDs
 * for the CringeStore migration workflow.
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '../../service-account-key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error(`❌ Service account key not found: ${serviceAccountPath}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
});

const db = admin.firestore();

const collections = [
  'store_products',
  'store_orders',
  'store_escrows',
  'store_wallets',
];

async function main() {
  try {
    for (const name of collections) {
      const snapshot = await db.collection(name).get();
      console.log(`\n📚 ${name}: ${snapshot.size} documents`);

      if (!snapshot.empty) {
        const sampleDocs = snapshot.docs.slice(0, 5).map(doc => doc.id);
        console.log(`   Sample IDs: ${sampleDocs.join(', ')}`);
      }
    }
  } catch (error) {
    console.error('❌ Error reading Firestore:', error.message);
    process.exit(1);
  } finally {
    await admin.app().delete();
  }
}

main();
