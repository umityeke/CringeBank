// Firestore'a test ürünleri ekleyen script
// Çalıştırma: node scripts/seed_store_products.js

const admin = require('firebase-admin');

// Firebase Admin SDK initialize (application default credentials kullanıyor)
admin.initializeApp({
  projectId: 'cringe-bank',
});

const db = admin.firestore();

const sampleProducts = [
  {
    title: 'iPhone 14 Pro Max 256GB',
    description: 'Sıfır ayarında, garantili iPhone. Kutusunda tüm aksesuarlarıyla birlikte.',
    price: 45000,
    category: 'electronics',
    imageUrl: 'https://via.placeholder.com/300x300.png?text=iPhone+14',
    sellerType: 'p2p',
    sellerId: 'test_seller_1',
    sellerName: 'Ahmet Y.',
    status: 'active',
    stock: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    title: 'PlayStation 5 Digital Edition',
    description: 'Az kullanılmış, 2 kol ve 5 oyun hediye.',
    price: 18000,
    category: 'gaming',
    imageUrl: 'https://via.placeholder.com/300x300.png?text=PS5',
    sellerType: 'p2p',
    sellerId: 'test_seller_2',
    sellerName: 'Mehmet K.',
    status: 'active',
    stock: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    title: 'MacBook Air M2 2023',
    description: 'Garantisi devam ediyor, çizik yok. 8GB RAM / 256GB SSD.',
    price: 32000,
    category: 'electronics',
    imageUrl: 'https://via.placeholder.com/300x300.png?text=MacBook+Air',
    sellerType: 'vendor',
    sellerId: 'vendor_techstore',
    sellerName: 'TechStore Official',
    status: 'active',
    stock: 5,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    title: 'Samsung Galaxy S23 Ultra',
    description: 'Yeni nesil flagship telefon, 12GB RAM, 512GB depolama.',
    price: 38000,
    category: 'electronics',
    imageUrl: 'https://via.placeholder.com/300x300.png?text=Galaxy+S23',
    sellerType: 'vendor',
    sellerId: 'vendor_mobilworld',
    sellerName: 'MobilWorld',
    status: 'active',
    stock: 3,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    title: 'Mekanik Klavye RGB',
    description: 'Gaming klavye, Cherry MX switch, RGB aydınlatmalı.',
    price: 2500,
    category: 'gaming',
    imageUrl: 'https://via.placeholder.com/300x300.png?text=Keyboard',
    sellerType: 'p2p',
    sellerId: 'test_seller_3',
    sellerName: 'Gamer_Ali',
    status: 'active',
    stock: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

async function seedProducts() {
  console.log('🌱 CringeStore test ürünleri ekleniyor...\n');
  
  const batch = db.batch();
  const productsRef = db.collection('store_products');

  for (const product of sampleProducts) {
    const docRef = productsRef.doc(); // auto-ID
    batch.set(docRef, product);
    console.log(`✅ ${product.title} (${product.sellerType}) - ₺${product.price}`);
  }

  await batch.commit();
  console.log(`\n🎉 ${sampleProducts.length} ürün başarıyla eklendi!`);
  process.exit(0);
}

seedProducts().catch((error) => {
  console.error('❌ Hata:', error);
  process.exit(1);
});
