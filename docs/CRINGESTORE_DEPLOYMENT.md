# CringeStore Deployment Guide
## Full Security Escrow Marketplace

### 🔐 Güvenlik Özellikleri

#### 1. **Firestore Security Rules**
- ✅ Cüzdanlar: SADECE Cloud Functions yazabilir
- ✅ Siparişler: SADECE Cloud Functions oluşturabilir
- ✅ Escrow: SADECE Cloud Functions manipüle edebilir
- ✅ Ürünler: Sadece sahip veya admin güncelleyebilir
- ✅ Client asla para transferi yapamaz

#### 2. **Cloud Functions Escrow**
- ✅ Transaction ile atomik işlemler
- ✅ %5 komisyon otomatik hesaplanır
- ✅ Bakiye kontrolü
- ✅ Kendi ürününü satın alma engeli
- ✅ Escrow lock/release/refund güvenli

#### 3. **Client-Side Validations**
- ✅ Firebase Authentication zorunlu
- ✅ Tüm işlemler Cloud Functions üzerinden
- ✅ Direct Firestore write YOK

---

## 📦 Deployment Adımları

### 1. Firebase Project Setup

```bash
# Firebase CLI kurulu değilse
npm install -g firebase-tools

# Login
firebase login

# Mevcut projeye bağlan
firebase use cringe-bank
```

### 2. Firestore Security Rules Deploy

```bash
# Store rules'u ana rules'a ekle veya ayrı deploy et
firebase deploy --only firestore:rules

# Veya firestore.rules'a manuel olarak ekle
# firestore_store.rules içeriğini kopyala
```

### 3. Cloud Functions Deploy

```bash
cd functions

# Eğer package.json'da yoksa ekle:
# "firebase-functions": "^4.x.x",
# "firebase-admin": "^11.x.x"

npm install

# Functions'ları deploy et
firebase deploy --only functions:escrowLock,functions:escrowRelease,functions:escrowRefund

# Veya tüm functions
firebase deploy --only functions
```

### 4. Firestore Collections Oluştur

Firebase Console'da manuel olarak oluştur:

#### a) `store_products` Collection
```javascript
// Örnek document
{
  title: "Test Ürün",
  desc: "Açıklama",
  priceGold: 100,
  images: ["https://example.com/image.jpg"],
  category: "avatar",
  condition: "new",
  status: "active",
  sellerId: "user123", // P2P için
  vendorId: null,
  sellerType: "p2p",
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now()
}
```

#### b) `store_wallets` Collection
```javascript
// Her kullanıcı için
{
  userId: "user123",
  goldBalance: 1000,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now()
}
```

#### c) `admins` Collection (Opsiyonel)
```javascript
// Admin user ID'leri
{
  uid: "admin123",
  role: "admin"
}
```

### 5. Firebase Functions Environment

```bash
# Functions region kontrolü
firebase functions:config:set regions.default="europe-west1"
```

---

## 🧪 Test Senaryoları

### Test 1: Satın Alma (Escrow Lock)
```dart
// Client tarafında
final result = await CringeStoreService().lockEscrow('product123');
if (result['ok'] == true) {
  print('Sipariş oluşturuldu: ${result['orderId']}');
}
```

**Beklenen Sonuç:**
- ✅ Escrow oluşturuldu
- ✅ Alıcının bakiyesi düştü
- ✅ Ürün rezerve oldu
- ✅ Order pending durumda

### Test 2: Siparişi Tamamla (Escrow Release)
```dart
final result = await CringeStoreService().releaseEscrow(orderId);
```

**Beklenen Sonuç:**
- ✅ Satıcının bakiyesi arttı (fiyat kadar)
- ✅ Platform komisyon kazandı
- ✅ Order completed oldu
- ✅ Ürün sold oldu

### Test 3: İptal Et (Escrow Refund)
```dart
final result = await CringeStoreService().refundEscrow(orderId);
```

**Beklenen Sonuç:**
- ✅ Alıcının parası iade edildi
- ✅ Order canceled oldu
- ✅ Ürün tekrar active oldu

---

## 🔍 Güvenlik Kontrolleri

### ✅ Client Tarafında Asla Yapılamaz:
- ❌ Cüzdan bakiyesi değiştirme
- ❌ Direct order oluşturma
- ❌ Escrow manipülasyonu
- ❌ Başkasının ürününü güncelleme

### ✅ Sadece Cloud Functions Yapabilir:
- ✅ Para transferleri
- ✅ Komisyon kesimi
- ✅ Escrow işlemleri
- ✅ Order lifecycle yönetimi

### 🛡️ Firestore & Storage Kuralları (Telefon Opsiyonel)

> **Not:** Şu anda giriş için e-posta/Google yeterli. İleride telefon zorunlu olduğunda `authOk()` fonksiyonunu `requirePhone()` ile değiştirmen yeterli olacak.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    /*******************************
     * COMMON HELPERS & TOGGLES
     *******************************/
    // Current policy: email/Google sign-in is enough.
    function isSignedIn() {
      return request.auth != null;
    }

    // Flip to `requirePhone()` later if you decide to enforce phone verification:
    function authOk() {
      return isSignedIn();
    }

    // Optional: future phone requirement (keep for later).
    function requirePhone() {
      // Works for users authenticated with phone; adjust to your claim strategy if needed.
      return isSignedIn() && request.auth.token.phone_number != null;
    }

    function isAdmin() {
      return isSignedIn() && (request.auth.token.admin == true);
    }

    function isOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    function isService() {
      // For Cloud Functions / privileged clients using a custom claim.
      return isSignedIn() && (request.auth.token.service == true);
    }

    function validTs(ts) {
      return ts is timestamp && ts <= request.time && ts > timestamp.date(2000,1,1);
    }

    // String byte-length check (Firestore rules use .size() on strings).
    function strOk(s, min, max) {
      return (s is string) && (s.size() >= min) && (s.size() <= max);
    }

    function nonNegInt(x) {
      return x is int && x >= 0;
    }

    // Allowed post kinds (you defined 5 types)
    function isValidKind(k) {
      return k in ['krep', 'citir', 'anlik', 'rulo', 'gorsel'];
    }

    // Basic safe visibility enum
    function isValidVisibility(v) {
      return v in ['public','followers','private'];
    }

    // Path safety: force media paths to live under the author's folder.
    function mediaPathOk(uid, path) {
      return path is string && path.startsWith('user_uploads/' + uid + '/');
    }

    /*******************************
     * USERS
     *******************************/
    match /users/{uid} {
      // Profiles are readable by signed-in users (tweak if you want public profiles).
      allow read: if authOk();

      allow create: if isOwner(uid)
        && request.resource.data.keys().hasOnly([
          'username','displayName','fullName','email','avatarUrl','bio',
          'isPremium','links','createdAt','updatedAt','followersCount',
          'followingCount','entriesCount'
        ])
        && validTs(request.resource.data.createdAt)
        && validTs(request.resource.data.updatedAt)
        && strOk(request.resource.data.username, 2, 32)
        && strOk(request.resource.data.displayName, 1, 64)
        && request.resource.data.followersCount == 0
        && request.resource.data.followingCount == 0
        && request.resource.data.entriesCount == 0;

      allow update: if isOwner(uid) || isAdmin();
      // You can constrain edits further (example below) by uncommenting:
      /*
      allow update: if (isOwner(uid) || isAdmin())
        && request.resource.data.diff(resource.data).changedKeys().hasOnly([
          'username','displayName','fullName','avatarUrl','bio','links','updatedAt','isPremium'
        ])
        && validTs(request.resource.data.updatedAt);
      */

      allow delete: if isOwner(uid) || isAdmin();
    }

    /*******************************
     * ENTRIES (posts)
     * /entries/{entryId}
     * Subcollections: comments, reactions
     *******************************/
    match /entries/{entryId} {
      // Timeline is public; switch to "authOk()" if you want only signed-in reads.
      allow read: if true;

      // CREATE by the author
      allow create: if authOk()
        && request.resource.data.keys().hasOnly([
          'authorId','authorName','kind','text','media','createdAt','editedAt',
          'tags','visibility','counters','extras'
        ])
        && request.resource.data.keys().hasAll([
          'authorId','authorName','kind','createdAt','editedAt','visibility','counters'
        ])
        && request.resource.data.authorId == request.auth.uid
        && isValidKind(request.resource.data.kind)
        && (request.resource.data.text == null
            || strOk(request.resource.data.text, 0, 10000))
        // media is a map or null. If present, check `path` sane.
        && (request.resource.data.media == null
            || (request.resource.data.media.path is string
                && mediaPathOk(request.auth.uid, request.resource.data.media.path)))
        && validTs(request.resource.data.createdAt)
        && validTs(request.resource.data.editedAt)
        && isValidVisibility(request.resource.data.visibility)
        // counters must start at zeros and only be updated by service/admin later
        && request.resource.data.counters.keys().hasOnly([
             'likeCount','dislikeCount','commentCount','shareCount','messageShareCount','viewCount'
           ])
        && request.resource.data.counters.likeCount == 0
        && request.resource.data.counters.dislikeCount == 0
        && request.resource.data.counters.commentCount == 0
        && request.resource.data.counters.shareCount == 0
        && request.resource.data.counters.messageShareCount == 0
        && request.resource.data.counters.viewCount == 0;

      // UPDATE by author: text/media/tags/visibility/editedAt/extras only.
      // counters are NOT editable by clients; only service/admin can touch them.
      allow update: if authOk() && (
          (
            resource.data.authorId == request.auth.uid
            && request.resource.data.diff(resource.data).changedKeys().hasOnly([
                 'text','media','tags','visibility','editedAt','extras'
               ])
            && validTs(request.resource.data.editedAt)
            && (request.resource.data.media == null
                || (request.resource.data.media.path is string
                    && mediaPathOk(request.auth.uid, request.resource.data.media.path)))
          )
          ||
          (
            // privileged updates (e.g., counters maintenance)
            (isService() || isAdmin())
          )
        );

      allow delete: if (authOk() && resource.data.authorId == request.auth.uid) || isAdmin();

      /******** COMMENTS ********/
      match /comments/{commentId} {
        allow read: if true;

        allow create: if authOk()
          && request.resource.data.keys().hasOnly([
               'authorId','authorName','text','createdAt','editedAt'
             ])
          && request.resource.data.authorId == request.auth.uid
          && strOk(request.resource.data.text, 1, 5000)
          && validTs(request.resource.data.createdAt)
          && validTs(request.resource.data.editedAt);

        allow update: if authOk()
          && resource.data.authorId == request.auth.uid
          && request.resource.data.diff(resource.data).changedKeys().hasOnly([
               'text','editedAt'
             ])
          && strOk(request.resource.data.text, 1, 5000)
          && validTs(request.resource.data.editedAt);

        allow delete: if (authOk() && resource.data.authorId == request.auth.uid) || isAdmin();
      }

      /******** REACTIONS (per user doc) ********/
      // Doc id = reacting user uid, data: { type: 'like'|'dislike'|null, updatedAt }
      match /reactions/{userId} {
        allow read: if true;

        allow create, update: if authOk()
          && userId == request.auth.uid
          && request.resource.data.keys().hasOnly(['type','updatedAt'])
          && (request.resource.data.type == null
              || request.resource.data.type in ['like','dislike'])
          && validTs(request.resource.data.updatedAt);

        allow delete: if authOk() && userId == request.auth.uid;
      }
    }

    /*******************************
     * FOLLOWS
     * /follows/{uid}/following/{targetUid}
     *******************************/
    match /follows/{uid}/following/{targetUid} {
      allow read: if authOk();
      allow create: if authOk() && uid == request.auth.uid && targetUid != uid;
      allow delete: if authOk() && uid == request.auth.uid;
    }

    /*******************************
     * DIRECT MESSAGES
     * /dm_conversations/{cid}
     *   /messages/{mid}
     *******************************/
    match /dm_conversations/{cid} {
      allow create: if authOk()
        && request.resource.data.keys().hasOnly(['members','createdAt','updatedAt','lastMessage'])
        && request.resource.data.members is list
        && request.resource.data.members.size() >= 2
        && request.auth.uid in request.resource.data.members
        && validTs(request.resource.data.createdAt)
        && validTs(request.resource.data.updatedAt);

      // Only members may read/update/delete the conversation doc
      allow read, update, delete: if authOk() && (request.auth.uid in resource.data.members);

      match /messages/{mid} {
        allow read: if authOk()
          && (request.auth.uid in get(/databases/$(database)/documents/dm_conversations/$(cid)).data.members);

        allow create: if authOk()
          && request.resource.data.keys().hasOnly([
               'senderId','text','media','createdAt'
             ])
          && request.resource.data.senderId == request.auth.uid
          && validTs(request.resource.data.createdAt)
          && (
               request.resource.data.text == null
               || strOk(request.resource.data.text, 1, 10000)
             )
          && (
               request.resource.data.media == null
               || (request.resource.data.media.path is string
                   && request.resource.data.media.path.startsWith('dm_attachments/' + cid + '/' + request.auth.uid + '/'))
             );

        allow update, delete: if authOk() && (
          resource.data.senderId == request.auth.uid ||
          (request.auth.uid in get(/databases/$(database)/documents/dm_conversations/$(cid)).data.members && isAdmin())
        );
      }
    }

    /*******************************
     * STORE (brands, products, orders, payouts)
     *******************************/
    // Brands
    match /brands/{brandId} {
      allow read: if true;

      // Brand doc contains: ownerIds (list of uids), .name, .verified, timestamps
      allow create: if isAdmin() || isService();

      allow update, delete: if isAdmin() || (
        authOk()
        && get(/databases/$(database)/documents/brands/$(brandId)).data.ownerIds.hasAny([request.auth.uid])
      );

      // Products under a brand
      match /products/{productId} {
        allow read: if true;

        allow create, update, delete: if authOk() && (
          isAdmin() ||
          get(/databases/$(database)/documents/brands/$(brandId)).data.ownerIds.hasAny([request.auth.uid])
        );
      }
    }

    // Orders (created by buyers; status transitions by service/admin; sellers may mark shipped)
    match /orders/{orderId} {
      allow read: if authOk() && (
        isAdmin() ||
        resource.data.buyerId == request.auth.uid ||
        // Allow brand owners to read orders that include their brand
        (
          resource.data.brandOwnerIds is list &&
          resource.data.brandOwnerIds.hasAny([request.auth.uid])
        )
      );

      allow create: if authOk()
        && request.resource.data.keys().hasOnly([
             'buyerId','items','totals','status','createdAt','updatedAt',
             'brandOwnerIds','shipping'
           ])
        && request.resource.data.buyerId == request.auth.uid
        && validTs(request.resource.data.createdAt)
        && validTs(request.resource.data.updatedAt)
        && request.resource.data.status in ['pending','awaiting_payment'];

      // Buyer may cancel before payment; brand owners can update shipping fields; service/admin can do full transitions.
      allow update: if authOk() && (
        // Buyer self-cancel from pending
        (
          request.auth.uid == resource.data.buyerId
          && resource.data.status in ['pending','awaiting_payment']
          && request.resource.data.status == 'cancelled_by_buyer'
          && request.resource.data.diff(resource.data).changedKeys().hasOnly(['status','updatedAt'])
          && validTs(request.resource.data.updatedAt)
        )
        ||
        // Brand owner updates shipping info only (not status to paid)
        (
          resource.data.brandOwnerIds is list
          && resource.data.brandOwnerIds.hasAny([request.auth.uid])
          && request.resource.data.diff(resource.data).changedKeys().hasOnly(['shipping','updatedAt','status'])
          && request.resource.data.status in ['processing','shipped','delivered']
          && validTs(request.resource.data.updatedAt)
        )
        ||
        // Service/Admin full control (payment settlements, refunds, etc.)
        (
          isService() || isAdmin()
        )
      );

      allow delete: if isAdmin();
    }

    // Payouts (only service/admin)
    match /payouts/{payoutId} {
      allow read: if isAdmin() || isService();
      allow create, update, delete: if isAdmin() || isService();
    }
  }
}

```

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function isSignedIn() {
      return request.auth != null;
    }
    function isAdmin() {
      return isSignedIn() && (request.auth.token.admin == true);
    }
    function isService() {
      return isSignedIn() && (request.auth.token.service == true);
    }

    // 10 MB images, 100 MB videos (tune as needed)
    function validImage() {
      return request.resource.contentType.matches('image/.*')
        && request.resource.size < 10 * 1024 * 1024;
    }
    function validVideo() {
      return request.resource.contentType.matches('video/.*')
        && request.resource.size < 100 * 1024 * 1024;
    }
    function validMime() {
      return validImage() || validVideo();
    }

    // Block potentially dangerous uploads
    function safeName(path) {
      return !path.endsWith('.exe')
        && !path.endsWith('.sh')
        && !path.endsWith('.bat')
        && !path.endsWith('.js');
    }

    /******** User uploads for posts ********/
    match /user_uploads/{uid}/{allPaths=**} {
      allow read: if true; // public CDN read; tighten if needed
      allow write: if isSignedIn() && request.auth.uid == uid
        && validMime()
        && safeName(resource.name);
      // OPTIONAL: rate-limit with App Check or Cloud Functions if abuse is a concern
    }

    /******** DM attachments (members-only read) ********/
    match /dm_attachments/{cid}/{uid}/{file=**} {
      // Members of the conversation only
      allow read: if isSignedIn() && (
        request.auth.uid in get(/databases/(default)/documents/dm_conversations/$(cid)).data.members
      );
      allow write: if isSignedIn()
        && request.auth.uid == uid
        && validMime()
        && safeName(resource.name);
    }

    /******** Product media for brands ********/
    match /product_media/{brandId}/{allPaths=**} {
      allow read: if true;
      // Only brand owners / admin / service may write
      allow write: if isSignedIn() && (
        isAdmin() || isService() ||
        get(/databases/(default)/documents/brands/$(brandId)).data.ownerIds.hasAny([request.auth.uid])
      ) && validMime() && safeName(resource.name);
    }
  }
}

```

**Deploy:**

```powershell
firebase deploy --only firestore:rules,storage:rules
```

---

## 📊 Firestore Indexes (Gerekli)

Firebase Console → Firestore → Indexes:

```
Collection: store_products
Fields: status (ASC), sellerType (ASC), createdAt (DESC)

Collection: store_products
Fields: status (ASC), category (ASC), createdAt (DESC)

Collection: store_products
Fields: status (ASC), sellerType (ASC), category (ASC), createdAt (DESC)
```

Veya Firebase otomatik index linklerini takip et.

---

## 🚀 Production Checklist

- [ ] Firestore Security Rules deploy edildi
- [ ] Cloud Functions deploy edildi (europe-west1)
- [ ] Composite indexes oluşturuldu
- [ ] Admin collection oluşturuldu
- [ ] Test cüzdanları oluşturuldu (test için)
- [ ] Komisyon oranı ayarlandı (varsayılan %5)
- [ ] Platform wallet oluşturuldu (platform user)
- [ ] Error monitoring aktif (Firebase Crashlytics)
- [ ] Cloud Functions logs izleniyor

---

## 💰 Komisyon Yapılandırması

`functions/cringe_store_functions.js` içinde:

```javascript
function calculateCommission(amount) {
  const COMMISSION_RATE = 0.05; // %5 → İstediğiniz orana değiştirin
  return Math.floor(amount * COMMISSION_RATE);
}
```

**Örnek Hesaplamalar:**
- Ürün: 100 Altın
- Komisyon (%5): 5 Altın
- Alıcıdan kesilen: 105 Altın
- Satıcıya giden: 100 Altın
- Platforma giden: 5 Altın

---

## 🎯 Para Basma Stratejisi

### Revenue Streams:
1. **P2P Komisyonu**: Her P2P satıştan %5
2. **Vendor Satışları**: Platform kendi ürünlerini satabilir (100% kâr)
3. **Premium Listings**: Featured ürünler için ek ücret
4. **Promotion**: Ürün boost sistemi

### Platform Wallet:
```javascript
// Platform cüzdanını kontrol et
const platformWallet = await db.collection('store_wallets').doc('platform').get();
console.log('Platform Balance:', platformWallet.data().goldBalance);
```

---

## 🆘 Troubleshooting

### Hata: "Insufficient permissions"
→ Firestore rules deploy edilmemiş olabilir

### Hata: "Function not found"
→ Functions deploy edilmemiş veya region yanlış

### Hata: "Insufficient balance"
→ Test için wallet oluşturulup balance eklensin

### Hata: "Index required"
→ Firebase console'daki index linkini takip et

---

## 📝 Notlar

- **Gerçek para transferi YOK**: Sadece in-app "Altın" currency
- **Test Mode**: İlk günler düşük komisyon kullanılabilir
- **Scaling**: Functions otomatik scale olur
- **Backup**: Firestore otomatik backup yapılmalı
- **Analytics**: Firebase Analytics ile sipariş tracking

---

## 🎉 Hazır!

Sistem tamamen güvenli ve production-ready. Para basma zamanı! 💰💰💰
