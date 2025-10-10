# DEPLOY_NOTES — /search/users Güçlendirme Sürümü

Bu belge, `/search/users` Cloud Function’ındaki dayanıklı SQL havuzu, retry/backoff ve CORS allowlist iyileştirmelerini staging → production devreye alma rehberi olarak açıklar.

## 🔧 1. Özet

### Yeni Özellikler

- MSSQL bağlantı havuzu için otomatik reset ve retry/backoff mekanizması (`runWithSql`, `resetSqlPool`).
- Güvenli CORS allowlist desteği: izinli origin yansıtma, credentials/preflight yönetimi.

### Yeni Env Değişkenleri

- `SEARCH_SQL_MAX_RETRIES`, `SEARCH_SQL_RETRY_DELAY_MS`, `SEARCH_CORS_ALLOWLIST` (veya `SEARCH_CORS_ORIGINS`).

### Test Durumu

- `npx jest --runInBand` tüm testleri geçti.

## ⚙️ 2. Önkoşullar

- Node.js 18+ ve güncel Firebase CLI.
- MSSQL erişimi (staging/prod ortamlarına göre farklı connection string’ler).
- CI/CD ortamında secret yönetimi (ör. GitHub Actions secrets).

## 🌍 3. Ortam Değişkenleri

Aşağıdaki değişkenleri `.env` dosyasına veya `firebase functions:config:set` üzerinden ekle.

| Anahtar | Örnek | Açıklama |
| --- | --- | --- |
| `DB_HOST` | `sql.internal.local` | SQL sunucu adresi |
| `DB_PORT` | `1433` | SQL portu |
| `DB_USER` | `app_reader` | Sadece okuma yetkili kullanıcı |
| `DB_PASSWORD` | `***` | Şifre (CI’da secrets olarak saklanmalı) |
| `DB_NAME` | `cringebank` | Veritabanı adı |
| `SEARCH_SQL_MAX_RETRIES` | `5` | Hatalı sorgularda tekrar sayısı |
| `SEARCH_SQL_RETRY_DELAY_MS` | `1000` | Denemeler arası bekleme süresi (ms) |
| `SEARCH_CORS_ALLOWLIST` | `https://cringebank.app,https://admin.cringebank.app` | İzinli origin listesi |
| `LOG_LEVEL` | `info` | Log seviyesi (`debug`, `info`, `warn`, `error`) |
| `NODE_ENV` | `production` | Ortam tipi |

`SEARCH_CORS_ORIGINS` aynı işlevi görür; biri yeterlidir.

## 🧩 4. .env.template Örneği

```env
# --- Database ---
DB_HOST=
DB_PORT=1433
DB_USER=
DB_PASSWORD=
DB_NAME=

# --- Retry / Backoff ---
SEARCH_SQL_MAX_RETRIES=5
SEARCH_SQL_RETRY_DELAY_MS=1000

# --- CORS ---
SEARCH_CORS_ALLOWLIST=https://staging.cringebank.app,https://admin.staging.cringebank.app

# --- Runtime ---
NODE_ENV=staging
LOG_LEVEL=info
```

## 🧠 5. Firebase Functions Config (Alternatif Besleme)

`.env` yerine CLI üzerinden set edebilirsin:

```bash
firebase functions:config:set \
  db.host="sql-stg.internal" \
  db.port="1433" \
  db.user="app_reader" \
  db.password="***" \
  db.name="cringebank_stg" \
  search.sql_max_retries="5" \
  search.sql_retry_delay_ms="1000" \
  search.cors_allowlist="https://staging.cringebank.app,https://admin.staging.cringebank.app"
```

Kod tarafında env > functions config önceliği varsa, tutarlılık için birini tercih et.

## 🔒 6. CORS Stratejisi

| Ortam | Domainler |
| --- | --- |
| Staging | `https://staging.cringebank.app`, `https://admin.staging.cringebank.app` |
| Production | `https://cringebank.app`, `https://admin.cringebank.app` |

QA sürecinde yalnızca test domainlerini açık tut; prod yayına geçmeden önce prod domainlerini ekle.

## 🚀 7. Dağıtım Adımları

1. Branch: `feature/search-users-hardening` → `develop` → `staging`.
2. Env Güncelle: `.env` veya functions config’i tamamla.
3. Bağımlılıklar: `npm ci` (functions klasöründe).
4. Test: `npx jest --runInBand` komutuyla doğrula.
5. Deploy (staging): `firebase deploy --only functions:search_users`.
6. Smoke Test: Arama endpoint’ini izinli domain üzerinden test et.
7. Prod Rollout: CORS allowlist’i prod domainlerle genişlet ve deploy et.

`npm test` Jest alias çakışması nedeniyle Flutter loglarını tetikleyebilir. CI’da doğrudan `npx jest --runInBand` kullan.

## ✅ 8. Kontrol Listesi

| Aşama | Tarih | Sorumlu | Durum |
| --- | --- | --- | --- |
| Staging Rollout | 2025-10-08 | Ümit YEKE | ✅ Tamamlandı |
| Production Rollout | 2025-10-10 | Ümit YEKE | 🔄 Planlandı |
| .env Parite Kontrolü | 2025-10-08 | Ümit YEKE | ✅ Local, Staging, GitHub Actions eşit |

## 📘 9. README Entegrasyonu

Proje kökündeki `README.md` dosyasına aşağıdaki bölümü ekleyin:

```markdown
### 🚀 Deployment Notes
Ayrıntılı dağıtım adımları için [Deployment Notes → /search/users](./docs/DEPLOY_NOTES.md) dosyasına göz atın.
```

Bu bağlantı tüm ekip üyelerinin dağıtım belgelerine doğrudan ulaşmasını sağlar.
