# CringeBank Telemetri Redaction Rehberi

Bu rehber, `docs/telemetry_events.md` dosyasindaki event semasini temel alarak hangi alanlarin anonimlestirilmesi veya filtrelenmesi gerektigini aciklar. Amac, KVKK/GDPR uyumlulugunu saglarken uretim ortaminda guvenilir telemetri toplamaktir.

## 1. Hashleme Kurallari

- `identifierHash`, `entryIdHash`, `productIdHash`, `challengeIdHash`: SHA-256 + uygulama icinde verilen salting mekanizmasi (`TelemetryService._salt`). Aynı salt tum cihazlarda degildir; backend counterpart environment degiskeni `CRINGEBANK_TELEMETRY_SALT` ile eslesmelidir.
- Hashlenmis alanlarin raw degeri loglanmaz, debug buildlerde dahi redakte edilir.

## 2. Maskeleme Kurallari

- Cihaz IP veya IP hash degeri gonderilmez. Gerekiyorsa sadece `deviceHint` alaninda genel platform bilgisi yer alir.
- Telefon veya email gibi veriler event payload’larinda yer almaz. Hata mesajlari `failureCode` gibi kod degerleriyle sinirlanir.

## 3. Saklama Politikasi

| Event Kategorisi | Saklama Suresi | Arxiv | Not |
| --- | --- | --- | --- |
| Kimlik & MFA (`login_*`, `otp_*`, `totp_*`, `passkey_*`) | 90 gun | Hayir | Anonim verilere ragmen 90 gun sonra topluca silinir. |
| Feed & Etkilesim (`feed_*`, `tagging_action`) | 180 gun | Evet | Agregasyon icin BigQuery arxivine aktarilabilir. |
| Finansal (`store_*`, `wallet_event`) | 365 gun | Evet | Vergi denetimi icin tutulan agregasyonlar hashli kimlikler uzerindendir. |
| Uygulama durumu (`app_*`) | 30 gun | Hayir | Performans metriği olarak kisa sure tutulur. |

## 4. Backend Filtreleme

- Telemetri pipeline'i, `CRINGEBANK_TELEMETRY_ALLOWED_EVENTS` ortam degiskeni ile beyaz liste modunda calistirilabilir. Liste disi eventler otomatik olarak redakte edilir ve disk loguna yazilmaz.
- Redakte edilen eventler icin audit log kaydi tutulur: `eventName`, `reason`, `receivedAt`.

## 5. Gelistirme/QA Notlari

- QA ortamlari icin `CRINGEBANK_USE_FIREBASE_EMULATOR=true` kullanilirken telemetri endpoint'i `http://localhost:8085/mock-telemetry` gibi bir mock servise yonlendirilebilir.
- Debug buildlerde telemetri gonderimi devre disi birakilmak istenirse `CRINGEBANK_TELEMETRY_ENDPOINT` bos birakilmalidir; servis otomatik olarak "no-op" moduna gecer.

## 6. Surumlama

- Rehber versiyonu: `2025-10-20`. Update gerektiginde `docs/telemetry_events.md` ve README icindeki telemetri bolumuyle birlikte guncellenmelidir.
