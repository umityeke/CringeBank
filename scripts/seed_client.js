// Firebase Emulator veya gerçek Firestore'a test ürünleri ekleyen basit script
const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, serverTimestamp } = require('firebase/firestore');

// Firebase config (firebase_options.dart'tan alınmış)
const firebaseConfig = {
  apiKey: "AIzaSyAP3OwPBxYUHNMSjNM4VB1qLBRuF2h6Xg4",
  authDomain: "cringe-bank.firebaseapp.com",
  projectId: "cringe-bank",
  storageBucket: "cringe-bank.firebasestorage.app",
  messagingSenderId: "617994662388",
  appId: "1:617994662388:web:2f89f36a44f1b3b5b73e3a",
  measurementId: "G-1HKQP9D3KS"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

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
  },
];

async function seedProducts() {
  console.log('🌱 CringeStore test ürünleri ekleniyor...\n');
  
  const productsRef = collection(db, 'store_products');

  for (const product of sampleProducts) {
    const docData = {
      ...product,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
    const docRef = await addDoc(productsRef, docData);
    console.log(`✅ ${product.title} (${product.sellerType}) - ₺${product.price} [${docRef.id}]`);
  }

  console.log(`\n🎉 ${sampleProducts.length} ürün başarıyla eklendi!`);
  process.exit(0);
}

seedProducts().catch((error) => {
  console.error('❌ Hata:', error);
  process.exit(1);
});
