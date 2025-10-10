# ☁️ SQL Gateway Backend Callable Plan

## 🎯 Amaç

Faz 1 kapsamında Cringe Store finansal işlemlerini Firestore'dan SQL Server'a taşıyarak aşağıdaki hedefleri gerçekleştirmek:

- `storeCreateOrder`, `storeReleaseEscrow`, `storeRefundEscrow`, `storeAdjustWallet` stored procedure'lerine doğrudan bağlanan Cloud Function callable uçlarını üretmek
- Mevcut `cringe_store_functions.js` akışını SQL tabanlı sürüme geçirip Firestore fallback'ini yalnızca geçici kurtarma modu olarak tutmak
- RBAC, App Check, hata haritalama ve telemetry gereksinimlerini sistematik şekilde karşılamak

## 🧱 Mevcut Durumun Özeti

- `functions/sql_gateway/procedures.js` prosedür tanımları hazır ve `createCallableProcedure` yardımcıları ile dışa açılabiliyor.
- `functions/index.js` içerisinde `sqlGatewayStore*` isimli exports mevcut fakat Flutter istemcisi hala `cringe_store_functions.js` çağrılarını kullanıyor.
- `cringe_store_functions.js`, `USE_SQL_ESCROW_GATEWAY` env bayrağına göre SQL/Firestore arasında seçim yapıyor; Firestore yolu legacy veriyi yönetiyor.

## 🗺️ Planlanan Değişiklikler

### 1. Konfigürasyon ve Ortam

- `USE_SQL_ESCROW_GATEWAY` varsayılanını `true` yap ve **yalnızca** acil durumlarda Firestore fallback'e dön.
- Yeni ortam değişkenleri:
  - `STORE_GATEWAY_TIMEOUT_MS` (varsayılan 10000) – MSSQL çağrıları için sürücü timeout'u
  - `STORE_GATEWAY_LOG_VERBOSE` – eşik değer ile hata ve performans loglarını genişletmek
- Jest/test ortamında prod guard bypass hâlihazırda çalışıyor → yeni handler'lar test doubles ile kullanılacak.

### 2. `functions/index.js`

- `sqlGatewayStore*` exports'larını **kamuya açık API** haline getirmek yerine iç modüle taşı.
- Flutter'ın çağırdığı fonksiyonlar `cringe_store_functions` içinde tutulacağından, index yalnızca modülün `exports` ettiği fonksiyonları yayımlayacak.
- Yeni internal helper: `const callSqlStoreProcedure = createCallableProcedure(key)` kullanarak modül içine dependency injection sağla.

### 3. `functions/sql_gateway/callable.js`

- `executeDefinition` içinde özel hata haritalama tabakası ekle (ör. SQL `CHECK` ihlali → `failed-precondition`).
- `enforcePolicy` çağrılarına telemetry alanı (`functions.logger`) ekle; hangi prosedür, hangi uid, latency.
- `createCallableProcedure` sonucu dönen handler, App Check zorunluluğunu `definition.requireAppCheck` üzerinden zaten yönetiyor → ekstra değişiklik gerekmiyor.

### 4. `functions/cringe_store_functions.js`

- *Public API* fonksiyonlarının (Flutter tarafından çağrılan `escrowLock`, `escrowRelease`, `escrowRefund`, `walletAdjust`) iç akışını aşağıdaki şekilde yeniden düzenle:
  1. **Ön doğrulama ve RBAC**: `requireAuth`, `isEscrowAdmin`, `AppCheck`.
  2. **SQL çağrısı**: `executeStoreGatewayProcedure('<key>')` kullan; Firestore kodunu ayrı helper'a taşı ve feature flag kapatıldığında devreye girsin.
  3. **Hata Çevirisi**: MSSQL hatalarını `functions.https.HttpsError` tiplerine çevir (ör. `SQL_GATEWAY_NOT_FOUND` → `not-found`).
  4. **Telemetry**: `functions.logger` ile `orderId`, `buyerUid`, `durationMs` logla.
- Yeni yardımcılar:
  - `mapSqlGatewayError(err)` → domain spesifik detaylar (ör. `ledger_insufficient_balance`).
  - `withSqlFallback(fnSql, fnFirestore, context)` → flag'e göre doğru yolu seç.
- Fallback Firestore yolu **yalnızca okuma** amaçlı olacak; yazan fonksiyonlar SQL'e yönlendirilecek.

### 5. `lib/services/store_backend_api.dart`

- Callable adlarını güncelle: `sqlGatewayStoreCreateOrder` yerine `cringeStoreEscrowLock` vs. tek noktaya indir.
- Hata mesajı map'ini SQL tarafındaki `details.reason` alanlarıyla eşleştir.
- Legacy Firestore path'lerini sadece read-only durumlarda bırak.

## 🔐 Güvenlik ve Yetkilendirme

| Prosedür | Cloud Function | Yetki Politikası |
| --- | --- | --- |
| `storeCreateOrder` | `escrowLock` | Auth zorunlu, App Check zorunlu, RBAC `store.orders:create` (buyer) |
| `storeReleaseEscrow` | `escrowRelease` | Auth zorunlu, RBAC `store.orders:release` (seller veya admin) |
| `storeRefundEscrow` | `escrowRefund` | Auth zorunlu, RBAC `store.orders:refund` + admin onayı |
| `storeAdjustWallet` | `walletAdjust` | Auth zorunlu, RBAC `store.wallets:adjust`, yalnızca admin rolleri |

Ek notlar:
- `PolicyEvaluator` hata mesajları client'a sızmamalı → `permission-denied` ile sonlandır.
- App Check header'ı bulunmazsa fonksiyon `failed-precondition` döndürmeli.

## 🧪 Test Stratejisi

1. **Unit/Jest**
   - `sql_gateway/callable.test.js` ekleyerek `createCallableProcedure` wrapper'ını mock MSSQL client ile test et.
   - `cringe_store_functions.test.js` içinde SQL yolu enable/disable senaryoları.
2. **Integration**
   - Emulator + MSSQL test instance ile `escrowLock` → `escrowRelease` happy path.
   - Negatif durumlar: yetersiz bakiye, yetkisiz kullanıcı, tekrar release denemesi.
3. **Client**
   - Flutter tarafında `StoreBackendApi` için mock callable yanıtları ile unit test.

## 🔄 Yayın Sırası

1. `USE_SQL_ESCROW_GATEWAY=true` ile beta ortamında Cloud Function'ları deploy et.
2. Flutter beta build'i (Staging) SQL yolu aktif şekilde yayınla.
3. Monitor: Cloud Logging'de hata oranı ve latency.
4. Firestore fallback'i read-only izlemeye al; 1 hafta sonra Firestore yazma yetkilerini kapat.

## 🧯 Rollback Planı

- `USE_SQL_ESCROW_GATEWAY=false` yaparak fonksiyonları Firestore fallback moduna geçir.
- SQL ledger snapshot'ını `functions/scripts/export_wallets.js` ile dışa aktar (yeni script gerekecek).
- Gerekiyorsa Firestore koleksiyonlarını `firebase_reset.ps1` rehberi ile geri yükle.

## ✅ Çıktılar

- Güncellenmiş backend callable kodu (`functions/cringe_store_functions.js`, `functions/sql_gateway/*`).
- Platform bağımsız mimari dokümantasyonu (`financial_sql_schema.md`, bu plan dokümanı).
- Jest testleri ve Flutter servis güncellemesi deployment checklist'ine eklendi.
