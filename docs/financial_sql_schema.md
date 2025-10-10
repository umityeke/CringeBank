# 💳 Finansal Modüller SQL Şeması Taslağı

Bu dosya, CringeBank hibrit mimari Faz 1 kapsamında Firestore'dan SQL Server'a taşınacak finansal modüllerin (wallet, escrow, orders, products) önerilen ilişkisel şemasını ve destekleyici stored procedure taslaklarını özetler.

## 🎯 Tasarım Amaçları

- Para hareketlerini **tek bir doğruluk kaynağı** (SQL) üzerinde tutmak
- Escrow ve wallet işlemlerini **ACID transaction** ile korumak
- Mevcut Cloud Functions katmanını (SQL Gateway) minimum değişiklikle yeni prosedürlere bağlamak
- Flutter istemcisine düşük gecikmeli, keystone sorgular sağlamak (callable + REST fallback)

## 🧱 Varsayımlar ve Konvansiyonlar

- Sunucu: Azure SQL / SQL Server 2019+ (UTF-8, `datetime2(3)` varsayıldı)
- Kimlik alanları için `INT IDENTITY` (sunucu tarafı), istemciye `NVARCHAR(64)` public id (ör. `OrderPublicId`)
- Para birimi CringeCoin/Gold -> `INT` (en küçük ünite 1 gold)
- Zaman damgaları: `datetime2(3)` ve varsayılan `SYSUTCDATETIME()`
- Tüm tablolar `dbo` şemasında; RBAC, stored procedure seviyesinde uygulanacak

## 📚 Tablo Şemaları

### 1. `dbo.Users`

> *Mevcut tablo; `sp_EnsureUser` kullanıyor. İlgili alanlar referans için tekrarlandı.*

| Kolon              | Tip              | Notlar |
| ------------------ | ---------------- | ------ |
| `UserId`           | `INT IDENTITY`   | PK |
| `AuthUid`          | `NVARCHAR(64)`   | Firebase UID, unique |
| `Email`            | `NVARCHAR(256)`  | unique (nullable) |
| `Username`         | `NVARCHAR(64)`   | unique |
| `DisplayName`      | `NVARCHAR(128)`  |  |
| `CreatedAt`        | `datetime2(3)`   | default `SYSUTCDATETIME()` |
| `UpdatedAt`        | `datetime2(3)`   | default `SYSUTCDATETIME()` |

#### İndeksler – Users

- `UX_Users_AuthUid` (unique)
- `UX_Users_Email` (unique, filtreli)
- `UX_Users_Username` (unique)

### 2. `dbo.StoreProducts`

| Kolon                | Tip              | Notlar |
| -------------------- | ---------------- | ------ |
| `ProductId`          | `INT IDENTITY`   | PK |
| `PublicId`           | `NVARCHAR(64)`   | Unique, client-facing |
| `SellerUserId`       | `INT`            | FK -> `Users(UserId)` (nullable; vendor ürünlerinde NULL) |
| `VendorUserId`       | `INT`            | FK -> `Users(UserId)` (nullable) |
| `SellerType`         | `TINYINT`        | 0=p2p, 1=vendor |
| `Title`              | `NVARCHAR(256)`  |  |
| `Description`        | `NVARCHAR(MAX)`  |  |
| `PriceGold`          | `INT`            |  |
| `CommissionRate`     | `DECIMAL(5,4)`   | default 0.0500 |
| `Status`             | `TINYINT`        | 0=active,1=reserved,2=sold,3=canceled |
| `CreatedAt`          | `datetime2(3)`   | default UTC |
| `UpdatedAt`          | `datetime2(3)`   | default UTC |

#### İndeksler – StoreProducts

- `UX_StoreProducts_PublicId`
- `IX_StoreProducts_StatusSellerType` (`Status`, `SellerType`, `CreatedAt` DESC)
- `IX_StoreProducts_SellerUserId`

### 3. `dbo.StoreWallets`

| Kolon              | Tip              | Notlar |
| ------------------ | ---------------- | ------ |
| `WalletId`         | `INT IDENTITY`   | PK |
| `UserId`           | `INT`            | FK -> `Users` |
| `BalanceGold`      | `INT`            | CHECK (`BalanceGold` >= 0) |
| `CreatedAt`        | `datetime2(3)`   | default UTC |
| `UpdatedAt`        | `datetime2(3)`   | default UTC |

#### İndeksler – StoreWallets

- `UX_StoreWallets_UserId` (unique)

### 4. `dbo.StoreWalletLedger`

| Kolon              | Tip              | Notlar |
| ------------------ | ---------------- | ------ |
| `LedgerId`         | `INT IDENTITY`   | PK |
| `WalletId`         | `INT`            | FK -> `StoreWallets` |
| `ExternalRef`      | `NVARCHAR(64)`   | (örn. `OrderPublicId`), nullable |
| `Source`           | `NVARCHAR(64)`   | `iap`, `order_release`, `manual_adjust`... |
| `AmountGold`       | `INT`            | Pozitif (kredi) / Negatif (debit) |
| `BalanceAfter`     | `INT`            | Ledger snapshot |
| `MetadataJson`     | `NVARCHAR(1024)` | opsiyonel |
| `CreatedAt`        | `datetime2(3)`   | default UTC |
| `CreatedBy`        | `NVARCHAR(64)`   | Auth UID / sistem |

#### İndeksler – StoreWalletLedger

- `IX_WalletLedger_WalletId_CreatedAt`
- `IX_WalletLedger_ExternalRef` (covering `Source`)

### 5. `dbo.StoreOrders`

| Kolon                | Tip              | Notlar |
| -------------------- | ---------------- | ------ |
| `OrderId`            | `INT IDENTITY`   | PK |
| `PublicId`           | `NVARCHAR(64)`   | Unique, escrow referansı |
| `ProductId`          | `INT`            | FK -> `StoreProducts` |
| `BuyerUserId`        | `INT`            | FK -> `Users` |
| `SellerUserId`       | `INT`            | FK -> `Users`, nullable (vendor) |
| `CommissionRate`     | `DECIMAL(5,4)`   |  |
| `PriceGold`          | `INT`            | Net fiyat |
| `CommissionGold`     | `INT`            | `ROUND(PriceGold * CommissionRate, 0)` |
| `TotalGold`          | `INT`            | `PriceGold + CommissionGold` |
| `Status`             | `TINYINT`        | 0=pending,1=completed,2=refunded,3=cancelled |
| `RequestedByUid`     | `NVARCHAR(64)`   | İsteği başlatan auth UID |
| `CreatedAt`          | `datetime2(3)`   | default UTC |
| `UpdatedAt`          | `datetime2(3)`   | default UTC |
| `CompletedAt`        | `datetime2(3)`   | nullable |
| `CancelledAt`        | `datetime2(3)`   | nullable |

#### İndeksler – StoreOrders

- `UX_StoreOrders_PublicId`
- `IX_StoreOrders_BuyerUserId_Status`
- `IX_StoreOrders_SellerUserId_Status`
- `IX_StoreOrders_ProductId`

### 6. `dbo.StoreEscrows`

| Kolon              | Tip              | Notlar |
| ------------------ | ---------------- | ------ |
| `EscrowId`         | `INT IDENTITY`   | PK |
| `OrderId`          | `INT`            | FK -> `StoreOrders` |
| `BuyerWalletId`    | `INT`            | FK -> `StoreWallets` |
| `SellerWalletId`   | `INT`            | FK -> `StoreWallets`, nullable (vendor -> platform cüzdanı) |
| `AmountGold`       | `INT`            |  |
| `CommissionGold`   | `INT`            |  |
| `Status`           | `TINYINT`        | 0=locked,1=released,2=refunded |
| `LockedAt`         | `datetime2(3)`   | default UTC |
| `ReleasedAt`       | `datetime2(3)`   | nullable |
| `RefundedAt`       | `datetime2(3)`   | nullable |
| `LockedByUid`      | `NVARCHAR(64)`   | İşlemi yapan auth UID |
| `LastActionUid`    | `NVARCHAR(64)`   | release/refund yapan auth UID |

#### İndeksler – StoreEscrows

- `IX_Escrows_OrderId`
- `IX_Escrows_Status`

### 7. `dbo.PlatformWallet`

Tek satırlık tablo (opsiyonel) — platform komisyonlarını ayrı izlemek için.

| Kolon           | Tip            | Notlar |
| --------------- | -------------- | ------ |
| `WalletId`      | `INT`          | PK, sabit 1 |
| `BalanceGold`   | `INT`          | |
| `UpdatedAt`     | `datetime2(3)` | |

Alternatif: Platform komisyonları `StoreWallets` içinde özel `UserId` ile tutulabilir (`UserId=1`).

## ⚙️ Stored Procedure Taslakları

Aşağıdaki prosedürler `functions/sql_gateway/procedures.js` içindeki callable tanımlarına doğrudan karşılık gelir.

### 1. `dbo.sp_EnsureUser`

- **Input**: `@AuthUid`, `@Email`, `@Username`, `@DisplayName`
- **Output**: `@UserId`, `@Created BIT`
- **İş**: Kullanıcı varsa döndür; yoksa `Users` + boş `StoreWallets` kaydı oluştur (0 bakiye).

### 2. `dbo.sp_GetUserProfile`

- **Input**: `@AuthUid`
- **Output**: `SELECT` ile profil + wallet snapshot (`BalanceGold`)

### 3. `dbo.sp_Store_CreateOrderAndLockEscrow`

- **Input**: `@BuyerAuthUid`, `@ProductId`, `@RequestedBy`, `@CommissionRate`, `@IsSystemOverride`
- **Output**: `@OrderPublicId`
- **Akış**:
  1. Buyer & seller wallet kayıtlarını kilitle (`UPDLOCK`)
  2. Buyer bakiyesini kontrol et (`BalanceGold >= TotalGold`)
  3. `StoreOrders` kaydı oluştur (`Status=pending`)
  4. `StoreEscrows` kaydı oluştur (`Status=locked`)
  5. Buyer wallet bakiyesini düş, ledger satırı yaz (`Source='order_lock'`)
  6. Public id üret (`FORMATMESSAGE('%s-%06d', 'ORD', @OrderId)`)

### 4. `dbo.sp_Store_ReleaseEscrow`

- **Input**: `@OrderPublicId`, `@ActorAuthUid`, `@IsSystemOverride`
- **Akış**:
  1. Order & escrow satırlarını `READPAST, UPDLOCK` ile çek
  2. Yetki kontrolü (buyer veya override rolleri)
  3. `Status` → `completed`, timestamp set
  4. Seller wallet + platform wallet güncelle
  5. Ledger satırları ekle (`order_release`, `commission_capture`)

### 5. `dbo.sp_Store_RefundEscrow`

- **Input**: `@OrderPublicId`, `@ActorAuthUid`, `@IsSystemOverride`, `@RefundReason`
- **Akış**:
  1. Order durum doğrulaması (`pending` olmalı)
  2. Escrow -> `refunded`
  3. Buyer wallet iade (`Ledger: order_refund`)
  4. Order status → `refunded`, reason log (`StoreOrders.RefundReason` opsiyonel sütun)

### 6. `dbo.sp_Store_AdjustWalletBalance`

- **Input**: `@TargetAuthUid`, `@ActorAuthUid`, `@AmountDelta`, `@Reason`, `@MetadataJson`, `@IsSystemOverride`
- **Akış**:
  1. Wallet + ledger kilidi
  2. Bakiye kontrolü (`AmountDelta` negatifse `BalanceGold + AmountDelta >= 0`)
  3. `StoreWalletLedger` satırı ekle
  4. Yeni bakiye döndür (`SELECT @NewBalance = BalanceGold`)

### 7. Okuma Amaçlı (Öneri)

- `dbo.sp_Store_GetWalletSnapshot(@AuthUid)` – bakiye + son N hareket
- `dbo.sp_Store_ListOrdersByUser(@AuthUid, @Role TINYINT)` – buyer/seller siparişleri
- `dbo.sp_Store_ListEscrowQueue(@Status)` – admin izleme

## 🔄 Veri Akışı

```mermaid
digraph G {
  rankdir=LR;
  Flutter [shape=box, label="Flutter Client"];
  Functions [shape=box, label="Cloud Functions (SQL Gateway)"];
  SQL [shape=cylinder, label="Azure SQL\n(Store_* tabloları)"];
  Flutter -> Functions [label="httpsCallable"];
  Functions -> SQL [label="Stored Proc"];
  SQL -> Functions [label="Result Sets"];
  Functions -> Flutter [label="Response"];
}
```

## 🧭 Migrasyon Notları

1. **Snapshot Alma**: Firestore `store_wallets`, `store_orders`, `store_escrows` koleksiyonları CSV/JSON olarak dışa aktarılmalı.
2. **Geçiş Sırası**
   - Users tablosunu Firebase Authentication ile eşleştir (`sp_EnsureUser` batch)
   - Wallet bakiyelerini `StoreWallets` + `StoreWalletLedger` seed et
   - Aktif sipariş/escrow kayıtlarını `StoreOrders` & `StoreEscrows` içine taşı
3. **Cutover**
   - Cloud Functions, SQL stored procedure çağırmaya geçirildiğinde Firestore yazma izinleri kaldırılmalı
   - Flutter istemcisindeki fallback mekanizması (Firestore) yalnızca okuma için saklanabilir
4. **Rollback Planı**: Ledger snapshot'ı SQL → Firestore dökümü olarak sakla; gerektiğinde eski Firestore koleksiyonları tekrar aktif edilebilir.

## ✅ Sonraki Adımlar

- [ ] Stored procedure'ler için T-SQL implementasyonu
- [ ] Unit test (Jest) tarafında prosedürlerin mock edilmesi
- [ ] Admin raporlama için read-only view'lar (`vw_StoreWalletBalances`, `vw_StoreOrderSummary`)
- [ ] Flutter tarafında callable isimleri / response şeması güncellemesi

Bu taslak, Faz 1’in kalan adımlarını (callable planı, Flutter entegrasyonu, migrasyon) detaylandırmak için temel referans dokümanıdır.
