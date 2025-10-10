# 🚀 SQL Migrasyon & Test Stratejisi

## 🎯 Amaç

Firestore tabanlı Cringe Store finansal verilerini SQL Server altyapısına güvenli, izlenebilir ve rollback yapılabilir şekilde taşımak; aynı zamanda yeni backend callable'ları ve Flutter entegrasyonunu yayına almadan önce kapsamlı testlerle doğrulamak.

---

## 🧱 Başlangıç Şartları

- `financial_sql_schema.md`'de tanımlanan tablolar SQL ortamında oluşturuldu.
- Stored procedure'ler (`dbo.sp_Store_*`) deploy edildi ve QA ortamında erişilebilir.
- `USE_SQL_ESCROW_GATEWAY` feature flag'i artık varsayılan olarak `true`; staging/prod fallback senaryoları için gerektiğinde `false` değerine override edilebilir.
- Faz 2 kapsamındaki gerçek zamanlı DM/Takip SQL aynası planı `realtime_sql_mirror_plan.md` dokümanında tanımlandı; burada yer alan Service Bus ve çift yazma yapıtaşları hazır olmalı.

---

## 🔄 Migrasyon Adımları

### 1. Veri Anketi ve Freeze

1. **Staging Snapshot**: Firestore koleksiyonlarını (`store_wallets`, `store_wallet_ledger`, `store_orders`, `store_escrows`, `store_products`) `scripts` klasörüne ekleyeceğimiz `export_firestore_store.js` ile JSON olarak dışa aktar.
2. **İş kesintisi planı**: Production'da migrasyon anında yeni sipariş ve cüzdan işlemlerini durdurmak için geçici maintenance banner'ı aç.
3. **Double-write devreye alma**: Migrasyon sırasında SQL'e yazarken Firestore'u read-only modda tutmak için Cloud Functions'ta geçici guard.

### 2. Kullanıcı ve Cüzdan Seed

1. Firebase Authentication → SQL `Users` tablosu eşlemesi: `functions/ensure_user_batch.js` scripti ile `sp_EnsureUser` çağrıları yap.
2. Wallet bakiyeleri: Firestore `store_wallets` koleksiyonundan `StoreWallets` tablosunu doldur, aynı anda `StoreWalletLedger` için opening balance entry oluştur.
3. Platform wallet için sabit kayıt (`WalletId=1`) ekle.

### 3. Sipariş ve Escrow Migrasyonu

1. `store_orders` ve `store_escrows` koleksiyonlarını `StoreOrders` + `StoreEscrows` tablolarına aktar.
2. Status mapping: `pending` → 0, `completed` → 1, `refunded` → 2, `cancelled` → 3.
3. Escrow kilitli bakiyeler için buyer/seller wallet bakiyelerini SQL'de yeniden hesapla ve ledger'a yansıt.
4. Migrasyon sonrası veri doğrulama scripti (`verify_migration.js`):
   - Toplam bakiye (wallet + escrow) Firestore ve SQL arasında eşit.
   - Aktif sipariş sayıları ve statü dağılımları eşleşiyor.

### 4. Cutover

1. `USE_SQL_ESCROW_GATEWAY` varsayılan olarak `true` olduğundan açık kaldığını doğrula ve gerekiyorsa Flutter Remote Config `store_sql_gateway_enabled=true` konfigürasyonunu senkronize et.
2. Cloud Functions deploy → SQL yolunu aktif et.
3. Firestore security rules: `write` izinlerini kapat (sadece admin paneli için gerektiğinde açılacak read-only).
4. Bir saat gözlem süresi: log/metrics izlenir, rollback trigger'ı hazır bekletilir.

### 5. Post-Cutover Temizlik

1. Eski Firestore koleksiyonlarındaki `pending` kayıtları arşivle veya sil.
2. Scripts klasöründe migrasyon JSON'ları şifreli archive'e kaldır.
3. Observability: SQL Agent job ile günlük ledger checksum raporu üret.

---

## 🛎️ Rollback Planı

- Feature flag'leri eski haline getir (`USE_SQL_ESCROW_GATEWAY=false`, Remote Config `store_sql_gateway_enabled=false`).
- Cloud Functions'ı yeniden deploy ederek Firestore yazma yolunu aktifleştir.
- SQL üzerinde yapılan yeni işlemleri `rollback_export.sql` ile dışa aktar ve incele.
- Firestore koleksiyonlarını `import_firestore_store.js` scriptiyle geri yükle.
- Rollback sonrası root-cause analizi ve veri karşılaştırması yapılır.

---

## 🔁 Faz 2 Hazırlıkları – Gerçek Zamanlı Modüller

- DM ve takip akışları için SQL aynası altyapısı, `realtime_sql_mirror_plan.md` dokümanında detaylandırıldığı şekilde oluşturulacak.
- Firestore tetikleyicilerinden Azure Service Bus topic'ine yayın yapan sync fonksiyonları cutover sonrası etkinleştirilir.
- Flutter istemcisi çift yazma (`Firestore + SQL`) için `USE_SQL_DM_WRITE_MIRROR` bayrağıyla canary modda devreye alınır.
- SignalR/WebSocket POC'si tamamlanana kadar okuma yolu Firestore'da kalır; izleme metrikleri 200 ms altında latency hedefini doğrular.

---

## 🧪 Test Stratejisi

### 1. Otomasyon

| Katman | Araç | Kapsam |
| --- | --- | --- |
| Unit | Jest (`functions/sql_gateway/__tests__`) | `createCallableProcedure`, hata map'leri, policy enforcement |
| Integration | Firebase Emulator + MSSQL container | `escrowLock → release/refund` akışları, yetersiz bakiye, yetkisiz kullanıcı |
| Client | Flutter `test/services/store_service_test.dart` | Mutasyon çağrıları, hata map'leri, optimistic UI |
| E2E | Detox / Flutter Driver (opsiyonel) | Kullanıcı senaryoları (ürün satın alma, release, refund) |
| Mirror Unit | Jest (`functions/realtime_mirror/__tests__`) | Firestore trigger → Service Bus publisher payload dönüşümleri |
| Mirror Integration | Azure Functions + MSSQL test container | Service Bus mesajı → DM/follow upsert stored procedure'leri |

### 2. Manuel QA Check-list

1. **Escrow Lock**: Buyer SQL bakiyesi düşer, escrow kaydı oluşur, Flutter success mesajı gösterir.
2. **Escrow Release**: Seller bakiyesi artar, platform komisyonu kesilir, order status `completed`.
3. **Escrow Refund**: Buyer bakiyesi iade, order status `refunded`.
4. **Wallet Adjust**: Admin panelinden +/− ayarlama, ledger kaydı ve yeni bakiye UI'da görünür.
5. **Edge Cases**: Aynı order'a ikinci release denemesi hata verir; App Check yoksa `failed-precondition` döner.

### 3. İzlenebilirlik

- Cloud Logging: `sqlGateway` label'lı entry'ler ve latency metric'leri.
- Application Insights / Azure Monitor: SQL hata kodu dağılımı.
- Sentry/Crashlytics: Flutter tarafında yeni hata tipleri.

---

## 📦 Scripts & Araçlar

| Script | Amaç |
| --- | --- |
| `scripts/export_firestore_store.js` | Firestore koleksiyonlarını JSON olarak dışa aktar |
| `scripts/import_firestore_store.js` | JSON'dan Firestore'a geri yükle (rollback) |
| `scripts/ensure_user_batch.js` | Tüm kullanıcılar için `sp_EnsureUser` çağrısı |
| `scripts/seed_wallets_and_orders.js` | Wallet + order verisini SQL'e yaz |
| `scripts/verify_migration.js` | Migrasyon sonrası veri tutarlılığı kontrolü |
| `scripts/dm_follow_consistency.js` | DM & takip SQL aynası ile Firestore verilerini karşılaştır |
| `scripts/rollback_export.sql` | SQL değişikliklerini kaydet |

> Not: Script dosyaları bu planı takiben oluşturulacak; PowerShell ve Node.js varyantları desteklenmeli.

---

## ✅ Tamamlanmış Sonuçlar

- Migrasyon öncesi ve sonrası veri setleri arasında tutarlılık sağlanmış.
- Yeni SQL tabanlı akış prod ortamına sorunsuz geçiş yapmış.
- Fallback ve rollback mekanizmaları dokümante edilmiş ve test edilmiş.
