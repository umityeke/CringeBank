# Kullanıcı Adı ve İsim-Soyadı Yeniden Yapılandırma Planı

Bu plan, CringeBank üyelik sözleşmesinde tanımlanan kullanıcı adı (username) ve isim-soyadı (displayName) kurallarını tek iterasyonda uygulamak için yapılacak kod, altyapı ve test güncellemelerini listeler.

## 1. Flutter (İstemci) Güncellemeleri

### 1.1 Profil Ekranı (`lib/screens/user_profile_screen.dart`)

- Kullanıcı adının yanında kopyalama ve profil linkini paylaşma aksiyonları eklenir.
- "Kullanıcı adını düzenle" butonu yalnızca kendi profilinde görünür.
- Düzenleme tıklandığında, `showModalBottomSheet` içinde aşağıdaki özelliklere sahip form açılır:
  - Giriş alanı küçük harfe zorlar; regex ihlallerinde anlık hata mesajı.
  - 2+ karakterde `usernameCheck` callable’ına 300 ms debounce ile istek atılır.
  - Hata ve uygunluk durumları (regex, blacklist, rezerve, cooldown) ayrı ikonlarla gösterilir.
  - 14 günlük cooldown bilgisi üstte gösterilir (kalan süre formatlanır).
  - Kaydet butonu yalnızca `valid && available && !cooldown` olduğunda aktif.
- Başarılı kayıtta profil üst kısmı yeni handle ile güncellenir, snackbar ile "14 gün sonra tekrar değiştirebilirsin" mesajı gösterilir.

### 1.2 İsim-Soyadı Düzenleme

- Aynı modal içinde ikinci sekme veya ayrı bir action kullanılarak displayName düzenlenebilir.
- 3–40 karakter arası, yasak karakter kontrolü (regex) yapılır.
- 14 günlük displayName cooldown bilgisi aynı şekilde gösterilir.

### 1.3 Servis Katmanı (`lib/services/user_service.dart`)

- Mevcut `isUsernameAvailable` vb. Firestore sorguları kaldırılır.
- Yeni `checkUsername`, `setUsername`, `setDisplayName` metodları callable fonksiyonlara bağlanır.
- Dönen `nextChangeAt`, `cooldown` ve hata kodları UI’a iletilecek şekilde exception sınıfları tanımlanır.
- Kullanıcının kendi profilini yenilemek için `refreshCurrentUser()` metodu callable başarısından sonra çağrılır; bu metot Firestore `users_public` aynasından veya mevcut `getUserById` ile senkron çalışır.

### 1.4 Model Güncellemeleri (`lib/models/user_model.dart`)

- Yeni alanlar eklenir:
  - `DateTime? nextUsernameChangeAt`
  - `DateTime? nextDisplayNameChangeAt`
  - `DateTime? lastUsernameChangeAt`
  - `DateTime? lastDisplayNameChangeAt`
- `User.fromMap` ve `toJson` metodları Firestore’daki `users_public` aynasında bu alanları okuyacak/güncelleyecek şekilde genişletilir.
- Kalan süre formatı için yardımcı getter’lar (`canChangeUsername`, `usernameCooldownRemaining`) eklenir.

### 1.5 Ortak Bileşenler

- Regex ve hata mesajlarını merkezi yerde tutmak için `lib/utils/username_policies.dart` dosyası oluşturulur.
- Debounce için mevcut util yoksa hafif bir helper eklenir (`ValueNotifier` veya custom debounce).

## 2. Cloud Functions

### 2.1 Genel Yardımcılar

- `functions/utils/usernamePolicy.js` dosyasında:
  - Regex sabiti, blacklist kontrolü, normalize fonksiyonu.
  - Cooldown kontrolünde kullanılacak tarih hesaplamaları.
  - Rate limit anahtarları (`rateLimiter('username:check', uid, {limit:10, window:60})`).
- `functions/utils/sqlClient.js`: Knex/Postgres bağlantısı mevcutsa kullanılır; yoksa `pg` ile minimal client.
- `functions/utils/outboxPublisher.js`: Outbox tablosuna insert fonksiyonu (`topic`, `payload`).

### 2.2 Callable Fonksiyonlar

- `exports.usernameCheck = functions.https.onCall(async (data, context) => { ... })`
  - Auth + App Check zorunluluğu.
  - Rate limit.
  - Regex + blacklist + reserved username kontrolü.
  - SQL’de mevcut mu sorgular (`SELECT 1 FROM users WHERE username = $1`).
  - Cooldown bilgisi için `username_history` tablosuna bakar (aktif rezervasyon).
  - Dönen payload: `{ valid, available, cooldown, reasons, nextChangeAt }`.
- `exports.usernameSet = functions.https.onCall(async (data, context) => { ... })`
  - Auth + email verified.
  - Transaction içinde:
    - Users tablosunda 14 gün kontrolü (`last_username_change_at + interval '14 days' <= now()`).
    - Yeni username’i update eder, eski username’i `username_history` tablosuna `reserved_until = now() + interval '30 days'` ile yazar.
    - `account_audit` tablosuna kayıt.
    - `users_history` outbox kaydı.
  - Firestore mirror’ı güncelleyen worker’a outbox kaydı.
  - Custom claims versiyonu artırır.
- `exports.displayNameSet = functions.https.onCall(async (data, context) => { ... })`
  - Benzer cooldown ve audit mantığı.

### 2.3 Worker Güncellemeleri (`functions/user_sync.js`)

- Outbox tüketicisi, `users_sync` topic payload’ında `username`, `displayName`, `nextUsernameChangeAt`, `nextDisplayNameChangeAt` alanlarını `/users_public/{uid}` dokümanına yazar.
- `updatedAt = admin.firestore.FieldValue.serverTimestamp()`.

### 2.4 Rate Limit & Abuse

- Mevcut rate-limiter yapısı yoksa `firebase-functions` memory cache veya Firestore tabanlı minimal sistem eklenir.
- Başarısız denemeler `functions.logger.warn` ile işlenir.

## 3. Veri Modeli ve Migration

### 3.1 SQL Migration Dosyası (`database/migrations/20251006_username_overhaul.sql`)

- `users` tablosuna yeni sütunlar: `last_username_change_at`, `next_username_change_at`, `last_displayname_change_at`, `next_displayname_change_at`.
- `username_history` ve `displayname_history` tablolarının oluşturulması.
- `account_audit` tablosuna `ip` ve `meta` alanları.
- `CHECK` constraint’lerinde regex.

### 3.2 Outbox Şeması

- `outbox_events` tablosuna `topic` + `payload` JSONB + `created_at` + `processed_at`.
- Worker için README notu.

### 3.3 Firestore Mirror

- `/users_public/{uid}` doküman yapısına `nextUsernameChangeAt`, `nextDisplayNameChangeAt` alanları eklenir (ISO string veya Timestamp).

## 4. Test Stratejisi

### 4.1 Unit

- Regex helper’ları için pozitif/negatif örnekler.
- Cooldown hesaplaması (14 gün, 30 gün rezerve) testleri.
- Blacklist kontrolü.

### 4.2 Integration (`functions/__tests__`)

- `usernameCheck` happy path, regex fail, blacklist, rezervasyon, cooldown.
- `usernameSet` başarılı değişim, 409 (taken), 429 (cooldown), 400 (regex).
- `displayNameSet` için benzer testler.

### 4.3 Flutter Widget Testi (`test/widgets/user_profile_username_edit_test.dart`)

- Kullanıcı handle modalı açılır, yanlış handle’da hata, doğru handle’da `Kaydet` aktif.
- Cooldown’da `Kaydet` inaktif ve uyarı görünür.

### 4.4 Manuel Smoke

- `flutter analyze`, `flutter test`.
- `npm test` veya `yarn test` Functions.
- Firebase emulator seti varsa callable’lar yerel test edilir.

## 5. Telemetri & Logging

- Flutter: `profile.username.check` ve `profile.username.set` eventleri `analyticsService` aracılığıyla gönderilir.
- Functions: `functions.logger.info` ile structured log (uid, oldUsername, newUsername, latency).
- Audit tabloları için IP adresi, user-agent (App Check) kaydı.

## 6. Dağıtım Notları

- Functions deployment sırası: `npm install`, `npm test`, `firebase deploy --only functions:usernameCheck,functions:usernameSet,functions:displayNameSet`.
- SQL migration önce çalıştırılmalı; outbox worker güncellemesi ve scheduler (cron) aktif edilmelidir.
- Mobil istemci güncellemesi zorunlu; eski sürümler yeni callable’ları kullanmak zorunda.

---
Bu plan doğrultusunda, ilgili todo başlıkları altında kod, test ve dokümantasyon güncellemelerini yapacağım.
