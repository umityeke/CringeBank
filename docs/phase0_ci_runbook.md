# Phase 0 CI / Staging Doğrulama Runbook

Bu rehber, hibrit mimarinin Faz 0 adımlarını (kimlik eşleşmesi + temel SQL gateway) otomatik olarak doğrulamak için hazırlanmış yeni komut zincirini açıklar. Komutlar `scripts/` çalışma alanı içinde çalıştırılır ve staging ortamına deploy öncesi pipeline aşamasında koşacak şekilde tasarlanmıştır.

## Ön Koşullar

- `SQLSERVER_HOST`, `SQLSERVER_USER`, `SQLSERVER_PASS`, `SQLSERVER_DB` ortam değişkenleri setlenmiş olmalı.
- Firebase Admin erişimi için `GOOGLE_APPLICATION_CREDENTIALS` veya eşdeğer ayarlar tanımlanmış olmalı.
- Node.js 18+ ve pnpm/npm yüklü olmalı.

## Hızlı Başlangıç

```powershell
cd scripts
npm install
npm run ci:phase0
```

Komut, aşağıdaki adımları sırasıyla gerçekleştirir:

1. `node sql/run_migrations.js --dry-run` — SQL migration ve stored procedure dosyalarını sıralı şekilde simulate eder.
2. İsteğe bağlı `node sql/backfill_auth_users.js --dry-run` — `--with-backfill-dry-run` bayrağı verilirse çalışır.
3. `node sql/verify_auth_sync.js --skip-migration --output=json` — Firebase Auth ↔ SQL tutarlılık raporu üretir.

Her adım başarısız olursa komut 1 ile döner ve pipeline’ı durdurur.

## Faydalı Bayraklar

Bayraklar `npm run ci:phase0 -- <flag>` şeklinde iletilir.

| Bayrak | Açıklama |
| --- | --- |
| `--skip-verify` | Auth/SQL tutarlılık kontrolünü atlar (sadece migration dry-run). |
| `--with-backfill-dry-run` | Dry-run backfill adımını ekler. |
| `--migrate-arg=<değer>` | `run_migrations.js` komutuna ek argüman geçirir (ör. `--migrate-arg=--only=20251007_02`). |
| `--verify-arg=<değer>` | `verify_auth_sync.js` komutuna ek argüman geçirir (ör. `--verify-arg=--limit=1000`). |
| `--backfill-arg=<değer>` | Backfill dry-run adımına ek argüman geçirir. |

## Pipeline Entegrasyonu Önerisi

- GitHub Actions veya Azure DevOps pipeline’ınızda `scripts` klasöründe `npm install` ve `npm run ci:phase0 -- --skip-verify` (veya gereken bayrak kombinasyonu) adımlarını ekleyin.
- Üretim dışı ortamlarda `--skip-verify` bayrağını düşürerek tam doğrulama gerçekleştirin.
- Script çıktıları detaylı log verdiğinden, pipeline loglarında hatanın hangi adımda oluştuğu kolayca izlenebilir.

## Başarısızlık Durumunda

1. Migration aşaması hata verirse SQL bağlantı bilgilerini ve gerekli yetkileri doğrulayın.
2. Backfill dry-run hataları, eksik kullanıcı profili verilerine işaret edebilir; loglarda `uid` bazlı detaylar yer alır.
3. Tutarlılık kontrolü satır bazında farklılıkları JSON formatında döker; pipeline loglarını saklayın ve düzeltme betiğiyle (örn. backfill) tekrar deneyin.

Runbook, SQL kimlik eşleşmesi tamamlandıktan sonra Faz 1’e geçmeden önce zorunlu kontrol listesi olarak kullanılmalıdır.
