# 🧠 CringeBank – Copilot Context (Enterprise, Security, Sync)

## 0) Kısa Tanım

CringeBank; Firebase Auth + Firestore (gerçek zamanlı/UX) ve MSSQL (finans, denetim, rapor) kullanan hibrit bir sosyal-finans ekosistemidir. Tüm yazma akışları idempotent event/outbox ile senkronize edilir; MSSQL Source-of-Truth (SoT), Firestore UI görünüm katmanıdır. Güvenlik: MFA/Passkey, App Check/reCAPTCHA, rate-limit, audit log, KVKK/GDPR uyumlu maskeleme.

## 1) Modül → Veri Katmanı Haritası

| Modül | Firestore (UI/Realtime) | MSSQL (SoT/Denetim) | Notlar (İş Kuralı) |
| --- | --- | --- | --- |
| Auth & Kayıt | `/users/{uid}` profil snapshot, consents kopyası | Users, Consents, LoginEvents, Wallets | Kayıt tamamlanınca event→SQL; claims/policy versiyonları set |
| Login | `lastLoginAt` yansıması | LoginEvents, FailedAttempts, Sessions | MFA zorunlu (admin); IP/device hash log |
| CringeYarışma | `competitions_view`, `competition_guesses` | Competitions, Rewards | Publish anında: FCM push + in-app message (tüm kullanıcılara) |
| CringeDrawer | `/users/{uid}/drawer_items` (denormalize ödül) | RewardRedemptions, WalletEntries | Kod “göster” tek sefer; reveal + redemption SQL’e log |
| CringeStore | `products_view`, `order_view` | Products, Orders, Escrow, WalletEntries | CG escrow: hold→release; %komisyon + vergi ayrımı |
| CG Cüzdan | `wallet_snapshot` | WalletEntries (double-entry) | Tüm transferler idempotent `request_id` ile |
| Feed/DM | Gönderi/mesaj görünümü, etkileşimler | PostsIndex, Signals | Moderasyon + gizlilik filtreleri SQL’de raporlanır |
| Arama | (yok veya hafif cache) | UsersIndex, PostsIndex, HashtagsIndex | TR-aware normalize, prefix index, rate-limit |
| Ayarlar | `/user_settings/{uid}` | UserSettings, AuditLogs, SecurityEvents | Kritik değişiklikte reauth + MFA zorunlu |

**Kural:** Yazma → önce MSSQL (finans/denetim), outbox event → Firestore denormalize görünüm. UI’da sadece Firestore okunur; ağır sorgular/raporlar SQL’den.

## 2) Enterprise Senkron (Idempotent Outbox)

Her kritik yazmada `request_id` zorunlu (idempotent).

- Outbox tablosu: `event_type`, `entity_id`, `payload`, `retry_count`, `next_attempt_at`.
- Consumer (Cloud Function/Worker): En fazla once-only semantik; backoff + dead-letter.
- Çakışma/tekrar durumda çift kayıt yok; “upsert by natural key” veya unique key ile korun.

### Temel Event’ler

`UserCreated`, `UserProfileUpdated`, `CompetitionPublished`, `GuessSubmitted`, `RewardCreated`, `WalletHoldPlaced`, `WalletReleased`, `WalletReversed`, `OrderCreated`, `OrderFulfilled`, `OrderDisputed`, `OrderCancelled`

## 3) Üst Seviye Güvenlik (Prod-Grade)

- Kimlik: Firebase Auth; MFA/Passkey (admin/superadmin zorunlu), e-posta/telefon doğrulama.
- Bot/Abuse: App Check/reCAPTCHA; OTP rate-limit; disposable domain reddi; IP/device hash.
- Erişim: Firestore Rules → sadece sahibi okur/yazar; admin path’leri ayrı. SQL erişimi yalnız sunucu.
- Oturum: Refresh token rotasyonu; “tüm cihazlardan çık” ve token revoke.
- Finansal Bütünlük: Double-entry ledger (WalletEntries). Release/Reverse işlemleri transaction ile.
- Gizlilik: IP/device fingerprint hash’li; PII loglanmaz; KVKK/GDPR saklama süreleri.
- Denetim: AuditLogs (kim, neyi, önce/sonra, ne zaman, ipHash, deviceHash).
- Alarmlar: OTP fail oranı, `login_fail` patlaması, outbox backlog, ledger mismatch, in-app abuse spike.

## 4) CringeYarışma Yayın & Ödül Akışı (kısa)

1. Admin Publish → MSSQL `Competitions.status=published`.
2. Outbox → `broadcast_competition`:
   - FCM push (topic/segment=all/eligible)
   - In-App Message (CringeBank resmi kanal)
3. Kullanıcı tahmini → Firestore `competition_guesses`.
4. `endTime` tetikleyici → SQL’de kazanan/ödül (`Rewards`).
5. Outbox `RewardCreated` → Firestore `/users/{uid}/drawer_items` (`status=new`).
6. Kazanana FCM: “Tebrikler! Ödül sandığına eklendi.”

## 5) CringeDrawer Kuralları (ödül sandığı)

- Denormalize kayıt: `type` (voucher|cg|badge), `brand`, `label`, `code` (masked), `status` (new|used|expired), `expiresAt`.
- “Kodu Göster/Kopyala” → tek sefer reveal; SQL’de `RewardRedemptions` log.
- `expiresAt` geçmişse auto-expire (scheduler).
- Güvenlik: sahibinden başkası göremez; kodlar masked; reveal ve redeem audit.

## 6) CringeStore Satış & Escrow (CG)

1. Satıcı ürün fiyatını CG ile girer → Ön-izleme: net CG = price - commission - tax - opsFee.
2. Alıcı satın al → Wallet HOLD (escrow).
3. Satıcı gönderir → Alıcı “Teslim aldım” → release: komisyon/vergi düş, net CG satıcıya.
4. İade/uyuşmazlıkta reverse entry; her şey transaction + idempotent.

## 7) API/Senaryo Guardrails (Copilot için kurallar)

- Yazma yolları: Finansal/sistem kritik: MSSQL → Outbox → Firestore. Sadece UI/okuma kolaylığı: Firestore (ör. feed görünümü).
- Her yazmada `request_id` kullan, idempotent işle.
- Claims/Policy sürümleri değişince kullanıcıdan tekrar onay iste (UI akışı).
- Feature Flags: yayın/rollback akışları: %5 → %25 → %100, eşik aşımında otomatik kapat.
- Rate-limit ve CORS allowlist katmanı (web istekleri).
- Test Et: Pozitif/negatif, güvenlik, senkron, performans (p95 hedefleri).

## 8) Hedef Performans (p95)

- Login: < 2s (captcha’sız), MFA TOTP: < 2s
- İlk feed kartı: < 1s (cache varsa)
- CG işlem (hold/release): < 3s
- Arama öneri: < 150ms, ilk sonuç: < 500ms
- Outbox→Firestore yansıması: < 5s

## 9) Özet Direktif (tek satır, Copilot Chat’e)

“CringeBank hibrit mimaride çalışır: MSSQL SoT, Firestore UI. Yazmaları idempotent outbox ile senkronize et; finansal işlemleri double-entry olarak kaydet; MFA/Passkey, App Check/reCAPTCHA, rate-limit, audit log zorunlu. Yarışma publish’te tüm kullanıcılara FCM + in-app mesaj yayımla; Drawer’a ödülleri denormalize et; Store’da CG escrow (hold→release→reverse) uygula. Tüm endpoint/iş akışlarında request_id ve transaction kullan, KVKK/GDPR gereği PII loglama.”

## Cringe Bankası

Flutter ile geliştirilmiş bu proje, paylaşımları Firestore üzerinde paylaşım türüne göre gruplanmış `cringe_entries_by_type/{paylasimTuru}/categories/{kategori}/entries` alt koleksiyonlarında tutan kurumsal seviyede bir akış servisi içerir. Bu döngüyü güçlendirmek için Firestore zaman aşımı yönetimi, kalıcı önbellek, telemetri ve indeks yapılandırmaları güncellendi.

## Mimari Genel Bakış

- **Flutter istemcisi**: Firestore akışlarını tüketir, TTL önbelleği ve telemetri katmanı sayesinde offline dayanıklılık sağlar.
- **ASP.NET Core 9 API**: Firebase ID token doğrulaması sırasında kullanıcı profillerini MSSQL `Users` tablosuna senkronlar ve istemcilere `/api/session/bootstrap` uç noktasıyla oturum başlatma sözleşmesi sunar.
- **Firebase Functions**: Firestore `users/{uid}` dokümanlarındaki değişiklikleri custom claim’lere aktarır, `claimsVersion` takibini yapar ve callable endpoint ile manuel yenilemeye izin verir.
- **Firestore & Storage kuralları**: Claim sürümü ve kullanıcı durumu doğrulaması ile yalnızca `active` ve güncel token’a sahip kullanıcıların yazmasına izin verir.

## Özellik Özeti

- Firestore `.snapshots()` akışında zaman aşımı 30 saniyeye çıkarıldı; ilk snapshot için daha geniş tolerans sağlar.
- `SharedPreferences` tabanlı TTL önbelleği sayesinde geçici kopmalarda veriler anında gösterilmeye devam eder.
- `_handleEnterpriseError` telemetri logları üretir, UI için durum/hint iletimi sağlar ve TimeoutException sayılarını izler.
- `firestore.indexes.json` dosyası `createdAt` alanı için sıralı indeks içerir.

## Admin Paneli & RBAC

- `MainNavigation` ekranında admin veya süper admin claim’lerine sahip kullanıcılar için sağ altta RBAC duyarlı bir kısayol çıkar; buton izin setine göre "Admin Paneli" veya "Süper Admin Paneli" etiketiyle görünür.
- Admin panelindeki menü öğeleri `AdminMenuCatalog.resolveMenu` üzerinden hesaplanır; izinler ve kategori scope’ları `AdminMenuAccessContext` ile değerlendirilir.
- Menu çözümleme davranışı `flutter test test/models/admin_menu_catalog_test.dart` komutuyla doğrulanabilir.

## Önbellek Davranışı

- Önbellek anahtarı: `enterprise_cringe_entries_cache_v1`
- TTL: 5 dakika. Süresi dolan veriler otomatik temizlenir.
- Test veya manuel kullanım için `CringeEntryService.primeCacheForTesting` / `getCachedEntriesForTesting` yardımcıları sağlandı.

## Telemetri ve UI İpuçları

- `CringeEntryService.streamStatus`, `streamHint` ve `timeoutExceptionCount` `ValueListenable` olarak dışa açılır.
- Timeout durumları `cringe_entries_stream_timeout` eventiyle Firebase Analytics’e raporlanır.
- UI, `streamHint` üzerinden “bağlantı yavaş” gibi mesajlar gösterebilir.

## Güvenlik ve Kimlik Doğrulama


### RBAC Policy Evaluator

- `functions/rbac/policyEvaluator.js` SQL tabanlı RBAC değerlendirmesini ve iki imza (two-man rule) süper admin akışını yönetir.
- Cloud Functions çalıştırmadan önce aşağıdaki ortam değişkenini tanımlayın:

```powershell
# functions klasöründe .env veya Firebase runtime config ile
$env:RBAC_DATABASE_URL = "postgres://user:pass@host:5432/cringebank"
```

- RBAC şemasını veritabanına uygulamak için `docs/rbac_policy_schema.sql` dosyasını çalıştırın.
- Manuel izin kontrolü için yeni callable `rbacCheckPermission` fonksiyonunu kullanın: `resource` ve `action` alanlarını iletin, gerekirse `scopeContext` ekleyin.

## Responsive Master Rulebook

CringeBank’ın tüm UI bileşenleri [CringeBank Responsive Master Rulebook](docs/responsive_master_rulebook.md) dokümanındaki breakpoint, grid, oran ve erişilebilirlik kriterlerine uymak zorundadır. Bu kurallar:

- xs-sm cihazlarda tek, md cihazlarda iki, lg-xl cihazlarda üç-dört, xxl cihazlarda beş-altı kolon layout’u zorunlu kılar.
- Kart ve görsel oranları için 16:9 ± %1 toleransını dayatır.
- Metinlerde `TextOverflow.ellipsis`, butonlarda minimum 44×44 px dokunma alanı gerektirir.
- Web tarafında Lighthouse `accessibility` ve `best-practices` skorlarının ≥ 90 olmasını şart koşar.

Herhangi bir breakpoint’te taşma veya scroll sapması tespit edilmesi build sürecinde başarısızlık nedeni sayılır.

## Testler

```powershell
# Flutter servis testleri
Set-Location 'c:/dev/cringebank'
flutter test test/services/cringe_entry_service_test.dart

# Backend API derleme ve test
Set-Location 'c:/dev/cringebank/backend'
dotnet build
dotnet test

# Firebase Functions birim testleri
Set-Location 'c:/dev/cringebank/functions'
npm test
```

## Firestore Yapılandırması


```powershell
Set-Location 'c:/dev/cringebank'
firebase deploy --only firestore:indexes,firestore:rules
```

- GitHub dosya boyutu limitine takılmamak ve gizli anahtarları paylaşmamak için `windows/firebase_sdk/` ve `windows/tools/` klasörleri depoya dahil edilmez ( `.gitignore` içerisinde).
- Windows derlemesi yapmak isteyen geliştiriciler, [Firebase C++ SDK](https://firebase.google.com/download/cpp) paketini indirip `windows/firebase_sdk/` dizinine çıkarmalıdır. ZİP arşivi repo dışında saklanmalıdır.
- `firebase_app_id_file.json` dosyası da aynı sebeple depoda yoktur; FlutterFire CLI ile yeniden üretilebilir:

```powershell
flutterfire configure --platforms windows
```

- Bu dosyalar lokal ortamda oluşturulduktan sonra `git status` çıktısında görünmemelidir. Görünüyorsa `.gitignore` kurallarının doğru uygulandığından emin olun.

### 🚀 Deployment Notes

Ayrıntılı dağıtım adımları için [Deployment Notes → /search/users](./docs/DEPLOY_NOTES.md) dosyasına göz atın.

## Faydalı Kaynaklar

- [Firebase kullanıcı senkronizasyonu rollout kılavuzu](docs/user_sync_rollout.md)
- [CringeStore backend implementasyonu](docs/CRINGESTORE_IMPLEMENTATION.md)
- [Firebase SSOT mimarisi](docs/cringe_entry_share_type_migration.md)


