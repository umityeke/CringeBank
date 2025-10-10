#!/usr/bin/env node

/**
 * Seeds minimal Firestore data for testing the Firestore→SQL migration.
 * Creates one document in each collection unless it already exists.
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

async function upsert(docRef, data) {
  const snap = await docRef.get();
  if (snap.exists) {
    console.log(`ℹ️  Document already exists: ${docRef.path}`);
    return;
  }
  await docRef.set(data);
  console.log(`✅ Seeded: ${docRef.path}`);
}

async function seedProducts() {
  const docRef = db.collection('store_products').doc('seed-product-1');
  await upsert(docRef, {
    title: 'Seed Product 1',
    desc: 'Example product for migration testing',
    priceGold: 1500,
    images: ['https://example.com/seed-product-1.png'],
    category: 'electronics',
    condition: 'USED',
    status: 'ACTIVE',
    sellerAuthUid: 'seller-seed-1',
    sellerType: 'P2P',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function seedOrders() {
  const docRef = db.collection('store_orders').doc('ORDER-SEED-001');
  await upsert(docRef, {
    id: 'ORDER-SEED-001',
    productId: 'seed-product-1',
    buyerAuthUid: 'buyer-seed-1',
    sellerAuthUid: 'seller-seed-1',
    sellerType: 'P2P',
    itemPriceGold: 1500,
    commissionGold: 150,
    totalGold: 1650,
    status: 'PENDING',
    paymentStatus: 'UNPAID',
    timeline: [{ status: 'CREATED', at: new Date().toISOString() }],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function seedEscrows() {
  const docRef = db.collection('store_escrows').doc('ESCROW-SEED-001');
  await upsert(docRef, {
    orderId: 'ORDER-SEED-001',
    buyerAuthUid: 'buyer-seed-1',
    sellerAuthUid: 'seller-seed-1',
    state: 'LOCKED',
    lockedAmountGold: 1650,
    releasedAmountGold: 0,
    refundedAmountGold: 0,
    lockedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function seedWallets() {
  const docRef = db.collection('store_wallets').doc('buyer-seed-1');
  await upsert(docRef, {
    authUid: 'buyer-seed-1',
    goldBalance: 5000,
    pendingGold: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function main() {
  try {
    await seedProducts();
    await seedOrders();
    await seedEscrows();
    await seedWallets();
    console.log('\n🎉 Firestore seed data ready for migration tests.');
  } catch (error) {
    console.error('❌ Error seeding Firestore:', error.message);
    process.exit(1);
  } finally {
    await admin.app().delete();
  }
}

main();
