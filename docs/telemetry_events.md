# CringeBank Telemetri Event Semasi

Bu belge, istemci tarafinda topladigimiz temel telemetri eventlerini ve alan yuzeylerini listeler. Tum eventler `TraceHttpClient` veya `TelemetryService` uzerinden gonderilir.

## Ortak Alanlar

| Alan | Tip | Aciklama |
| --- | --- | --- |
| `eventName` | string | Event kimligi (asagidaki tabloda yer alir). |
| `occurredAt` | ISO8601 string | UTC zaman damgasi. |
| `userId` | string? | Giris yapmis kullanicinin UID degeri; anonim oturumlarda gonderilmez. |
| `sessionId` | string | Cihaz bazli oturum kimligi; `UUIDv4`. |
| `deviceHint` | string | Platform + versiyon bilgisi (`ios/17.0`, `android/14`, `web/chrome`). |
| `appVersion` | string | Semantik versiyon (`1.0.0+1`). |
| `requestId` | string | Idempotent takip icin kullanilan 128 bit hex. |

## Event Listesi

| Event | Context | Ozgun Alanlar | PII/Redaction |
| --- | --- | --- | --- |
| `login_attempt` | Email/kullanici adi ile giris butonuna basildiginda | `identifierHash`, `mfaType`, `captchaShown` | `identifierHash` SHA-256 ile maskelenir; raw deger tutulmaz. |
| `login_failure` | Giris hatasi alindiginda | `failureCode`, `remainingAttempts`, `captchaRequired` | Kodlar backend hata sozlugu ile sinirli; metin gonderilmez. |
| `login_success` | Giris basarili oldugunda | `mfaType`, `latencyMs`, `deviceVerification` | PII icermez. |
| `feed_impression` | Feed ilk kartlari yuktugunda | `segment`, `count`, `latencyMs` | PII icermez. |
| `feed_interaction` | Kaydirma/like/share/report aksiyonlari | `action`, `entryIdHash`, `position`, `timeToActionMs` | `entryIdHash` SHA-256; rapor sebebi sozluk ID'si olarak gelir. |
| `otp_sent` | OTP veya magic link gonderimi | `channel`, `cooldownSeconds` | Kanal bilgisi (sms/email); kullanici identifiersiz raporlanir. |
| `otp_verify_failure` | OTP dogrulama hatasi | `channel`, `attemptNumber`, `lockThreshold` | PII yok. |
| `totp_verify_failure` | Authenticator kod hatasi | `attemptNumber`, `lockThreshold` | PII yok. |
| `passkey_start` | Passkey dogrulama tetiklenmesi | `challengeIdHash`, `fallbackShown` | `challengeIdHash` SHA-256. |
| `passkey_complete` | Passkey basariyla tamamlandiginda | `latencyMs`, `fallbackUsed` | PII yok. |
| `registration_step` | Kayit akisi adim gecisi | `step`, `validationErrors`, `latencyMs` | Hata kodlistesi ID bazlidir; serbest metin yok. |
| `tagging_action` | Hashtag/mention/etiket ekleme | `action`, `targetType`, `targetIdHash` | Tum kimlikler hashlenir. |
| `store_order_submit` | CringeStore siparis olusturma | `productIdHash`, `totalCents`, `currency` | Para degerleri sayi olarak; musteri kimligi hashlenir. |
| `wallet_event` | Wallet hold/release/reverse | `eventType`, `amountCents`, `ledgerRequestId` | PII yok. |
| `app_foreground` | Uygulama on plana geldiginde | `previousState`, `elapsedMs` | PII yok. |
| `app_background` | Uygulama arka plana gectiginde | `reason`, `elapsedMs` | PII yok. |

## Event Gonderim Kurallari

1. Tum eventlerde `requestId` zorunludur; aksi durumda olay backend tarafinda reddedilir.
2. Kullanici tanimlayan alanlar (email, telefon, ip vb.) raw olarak gonderilmez; ilgili hash fonksiyonlari `TelemetryService` icinde uygulanir.
3. Eventler en gec 5 saniye icinde flush edilir; offline durumda gecici disk kuyruğu kullanilir.
4. Backend redaksiyon kurallari icin `docs/telemetry_redaction_guide.md` belgesine bakilmalidir.

## Surumlama

- Semanin versiyonu: `2025-10-20`. Degisiklik yapildiginda README ve redaction rehberi ile birlikte guncellenmelidir.
