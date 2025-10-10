# 🦋 Flutter Store SQL Entegrasyon Planı

## 🎯 Hedef

Cringe Store Flutter istemcisini, Firestore ağırlıklı mevcut mimariden SQL tabanlı escrow & cüzdan gateway'ine geçirirken kullanıcı deneyimini korumak, geriye dönük uyumluluk sağlamak ve minimum kesintiyle canlı ortamda yayınlamak.

## 📦 Mevcut Durum (Özet)

- `lib/services/store_service.dart` Firestore koleksiyonlarını (`store_products`, `store_wallets`, `store_orders`, `store_escrows`) doğrudan okuyup yazıyor.
- `lib/services/store_backend_api.dart` REST fallback'ı bulunuyor fakat çoğu mutasyon için Cloud Function çağrıları (`escrowLock`, `escrowRelease` vb.) Firestore yoluna gidiyor.
- Uygulama, `StoreService` üzerinden Stream tabanlı snapshot'larla UI'ı besliyor; optimistic update mekanizmaları yok, doğrudan Firestore snapshot'ını gösteriyor.

## 🧭 Gelecek Mimari

```mermaid
Flutter Widget -> StoreRepository -> StoreBackendApi
                               |-> (SQL callable) escrowLock / release / refund / adjust
                               |-> Firestore (read-only sync)
```

- **Write path** SQL gateway üzerinden gerçekleşecek (Callable Functions).
- **Read path** ilk aşamada Firestore snapshot'larıyla devam edecek; SQL tarafındaki veriler periyodik job ile Firestore'a yansıtılacak veya temporary dual-write uygulanacak.

## 🗺️ Adım Adım Plan

### 1. Servis Katmanı Refaktörü

- `StoreBackendApi`
  - Callable isimlerini `sqlGatewayStoreCreateOrder` yerine domain odaklı hale getir (`createEscrowOrder`, `releaseEscrow`, `refundEscrow`, `adjustWallet`).
  - Response modellerini güncelle: SQL gateway `newBalance`, `status`, `reason` alanlarını expose et.
  - Hata haritalama: `HttpsError` `details.reason` alanını Flutter `StoreErrorReason` enum'ına dönüştür.

- `StoreService`
  - Mutasyon metodları (`startPurchase`, `completePurchase`, `refundOrder`, `adjustWallet`) Firestore yazımlarını kaldırıp `StoreBackendApi` çağrılarına yönlendirilecek.
  - Firestore yazma kodu ayrı private helper'a taşınarak feature flag ile kontrol edilecek (rollback için).
  - Success sonrası Firestore cache'i invalid etmek için `await` ile `store_orders` doc'u fetch etmek veya `onSnapshot` beklemek.

### 2. Durum Yönetimi

- `Riverpod`/`Provider` kullanan ekranlarda (örn. `StoreScreen`, `WalletScreen`) refactor:
  - `OrderStatus` ve `WalletBalance` state'leri API dönüş değerlerine göre güncellenecek.
  - Mutasyon sonrasında optimistic UI: pending state göster, `newBalance` varsa UI'da hemen güncelle.

### 3. Hata Deneyimi

- API katmanında domain hatalarını (yetersiz bakiye, yetki reddi, escrow zaten release edilmiş vb.) `StoreFailure` modeline taşı.
- UI katmanında localized mesajlar: `wallet_insufficient_balance` → "Yetersiz bakiye".

### 4. Konfigürasyon ve Feature Flag

- `USE_SQL_ESCROW_GATEWAY` değerini Flutter tarafında da izlemek için Remote Config anahtarı (örn. `store_sql_gateway_enabled`).
- Flag kapalıyken eski Firestore yazma kodu devreye girecek (geçici).

### 5. Test Stratejisi

- **Unit**: `StoreBackendApi` için `mockCallable` ile happy path + hata senaryoları.
- **Widget/Integration**: Escrow akışını `store_service_test.dart` içinde sahte backend ile test et.
- **Manual QA**: Staging ortamında SQL gateway ile: ürün satın alma, satıcı release, admin refund, admin wallet adjust.

## 🧱 Dosya Bazlı Değişiklikler

| Dosya | İşlem |
| --- | --- |
| `lib/services/store_backend_api.dart` | Callable isimleri, request/response modelleri, hata map'i |
| `lib/services/store_service.dart` | Firestore yazmaları kaldır, SQL çağrılarına yönlendir |
| `lib/models/store_models.dart` (varsa) | Yeni response yapıları |
| `lib/screens/store/**` | Yeni state akışına uygun UI güncellemeleri |
| `test/services/store_service_test.dart` | Yeni mutasyon yolunu kapsayan testler |

## 🔄 Yayın Süreci

1. Kod değişiklikleri + unit testler.
2. Staging build: SQL gateway flag açık.
3. QA senaryoları: escrow lock, release, refund, wallet adjust.
4. Production deploy → Remote Config'te `store_sql_gateway_enabled=true`.
5. Gözlemleme: Cloud Logging, Sentry, Firebase Crashlytics.

## 🧯 Rollback

- Remote Config flag'i `false` yaparak yazma işlemlerini tekrar Firestore yoluna yönlendir.
- Flutter sürümü gerekmeden `StoreService` fallback kullanmaya devam eder.

## 📌 Notlar

- Firestore read path'i SQL gerçeğiyle senkronize etmek için ayrı `sync` job planlanacak (Faz 1.5).
- Wallet ledger ekranı SQL API'den gelen `newBalance` bilgisi ile anında güncellenebilir; Firestore snapshot gecikmesini minimize eder.
