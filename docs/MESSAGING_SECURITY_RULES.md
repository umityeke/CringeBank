# Direct Messaging - Firebase Security Rules

Bu dosya, CringeBankası uygulamasının gelişmiş mesajlaşma sistemi için Firebase güvenlik kurallarını içerir.

## 📋 İçindekiler

### 1. Firestore Rules (`firestore.rules`)
- **Conversations (Sohbetler)**: DM sohbet odaları
- **Messages (Mesajlar)**: Mesaj içerikleri
- **Blocks (Engellemeler)**: Kullanıcı engelleme sistemi

### 2. Storage Rules (`storage.rules`)
- **DM Medya**: `dm/{cid}/{mid}/{fileName}` yolu üzerinden medya paylaşımı

### 3. Realtime Database Rules (`database.rules.json`)
- **Online Status**: Kullanıcı çevrimiçi durumu
- **Typing Indicators**: Yazıyor göstergesi

## 🔐 Güvenlik Özellikleri

### Email Doğrulaması
✅ Tüm işlemler için `email_verified == true` şartı

### Üyelik Kontrolü
✅ Sadece sohbet üyeleri mesajları okuyabilir/yazabilir

### Anti-Spam
✅ Mesaj gönderimi için `rateKey: "ok"` kontrolü (Cloud Functions tarafından set edilir)

### Engelleme Sistemi
✅ İki yönlü engelleme kontrolü
✅ Engellenmiş kullanıcılardan mesaj alınamaz

### Mesaj Düzenleme
✅ Sadece gönderen düzenleyebilir
✅ 15 dakikalık düzenleme penceresi
✅ `(düzenlendi)` bayrağı otomatik eklenir
✅ Düzenleme geçmişi saklanır

### Mesaj Silme

#### Only-Me (Sadece Bende Sil)
- `deletedFor.<myUid> = true` ile işaretlenir
- Karşı taraf mesajı görmeye devam eder
- Geri alınamaz

#### For-Both (Herkesten Sil)
- `tombstone.active = true` ile işaretlenir
- Her iki taraftan da silinir
- Geri alınamaz
- Düzenleme artık yapılamaz

## 🚀 Deployment (Yayınlama)

### Tüm Rules'ları Deploy Et
```powershell
firebase deploy --only firestore:rules,storage:rules,database:rules
```

### Sadece Firestore Rules
```powershell
firebase deploy --only firestore:rules
```

### Sadece Storage Rules
```powershell
firebase deploy --only storage:rules
```

### Sadece Realtime Database Rules
```powershell
firebase deploy --only database:rules
```

## 📊 Gerekli Firestore Indexes

### Conversations Collection
```javascript
// members array-contains + updatedAt desc
{
  "collectionGroup": "conversations",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "members", "arrayConfig": "CONTAINS" },
    { "fieldPath": "updatedAt", "order": "DESCENDING" }
  ]
}
```

### Messages Subcollection
```javascript
// createdAt asc (zaten otomatik oluşur)
{
  "collectionGroup": "messages",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "createdAt", "order": "ASCENDING" }
  ]
}
```

Firebase Console'da bu indexleri oluşturmak için:
1. Firebase Console → Firestore Database → Indexes
2. "Add Index" butonuna tıkla
3. Yukarıdaki konfigürasyonları gir

## 🛠️ Cloud Functions Gereksinimleri

Aşağıdaki Cloud Functions implement edilmelidir:

### 1. `sendMessage`
- Rate limiting kontrolü
- `rateKey: "ok"` ekleme
- `editAllowedUntil = createdAt + 15 dakika` set etme
- Conversation'ın `lastMessage` ve `updatedAt` güncelleme

### 2. `editMessage`
- Edit penceresi kontrolü
- `edited.active = true`, `edited.at`, `edited.by` set etme
- `edited.version` artırma
- İçerik moderasyonu (opsiyonel)

### 3. `deleteMessage`
- `tombstone.active = true` set etme
- `tombstone.by`, `tombstone.at` ekleme
- Storage'daki medyaları silme (eğer varsa)

### 4. `setReadPointer`
- Conversation'daki `readPointers.<uid>` güncelleme
- Okunmamış mesaj sayısını güncelleme

## 📁 Dosya Yapısı

### Conversations Document
```typescript
{
  id: string,
  members: string[],              // [uid1, uid2]
  isGroup: boolean,               // false for DM
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastMessage: {
    text: string,
    senderId: string,
    createdAt: Timestamp
  },
  readPointers: {
    [uid]: Timestamp              // Her kullanıcının son okuma zamanı
  }
}
```

### Message Document
```typescript
{
  id: string,
  senderId: string,
  text: string | null,
  media: string[] | null,         // Storage paths
  createdAt: Timestamp,
  rateKey: "ok",                  // Functions tarafından set edilir
  editAllowedUntil: Timestamp,    // createdAt + 15 dakika
  
  // Düzenleme bilgisi (opsiyonel)
  edited?: {
    active: boolean,
    at: Timestamp,
    by: string,
    version: number
  },
  
  // Sadece bende silme (opsiyonel)
  deletedFor?: {
    [uid]: true
  },
  
  // Herkesten silme (opsiyonel)
  tombstone?: {
    active: boolean,
    by: string,
    at: Timestamp
  }
}
```

### Block Document
```typescript
{
  // Path: blocks/{ownerUid}/targets/{targetUid}
  blockedAt: Timestamp,
  reason: string | null
}
```

## ⚠️ Önemli Notlar

1. **Email Verification**: Tüm kullanıcılar email doğrulaması yapmış olmalı
2. **Rate Limiting**: `sendMessage` function'ında mutlaka rate limiting implement edin
3. **Media Upload**: Medya önce Storage'a yüklenmeli, sonra message'da path saklanmalı
4. **Tombstone**: Tombstone edilmiş mesajların medyaları da Storage'dan silinmeli
5. **Edit Window**: 15 dakikalık pencere Functions'ta da kontrol edilmeli
6. **Indexes**: Yukarıdaki indexler mutlaka oluşturulmalı

## 🧪 Test Senaryoları

### ✅ Başarılı Senaryolar
- Email doğrulanmış kullanıcı mesaj gönderebilir
- Kullanıcı kendi mesajını düzenleyebilir (15 dk içinde)
- Kullanıcı kendi mesajını sadece kendinden silebilir
- Kullanıcı kendi mesajını herkesten silebilir
- Engellenen kullanıcıya mesaj gönderilemez

### ❌ Başarısız Senaryolar
- Email doğrulanmamış kullanıcı mesaj gönderemez
- Kullanıcı başkasının mesajını düzenleyemez
- 15 dakika sonra mesaj düzenlenemez
- Tombstone edilmiş mesaj düzenlenemez
- rateKey olmadan mesaj gönderilemez

## 📞 Destek

Sorularınız için: [GitHub Issues](https://github.com/umityeke/CRINGE-BANKASI/issues)

---

**Son Güncelleme:** 5 Ekim 2025
**Versiyon:** 1.0.0
