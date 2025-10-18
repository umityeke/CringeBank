# Frontend TODO (Flutter)

## 1. Kayıt Paneli (Registration Flow)

- [x] Kimlik ve şifre ekranlarını Flutter ile uygula (e-posta/telefon seçimi, şifre politikası doğrulamaları).
- [x] OTP üretimi/yeniden gönderme ekranını ve cooldown mantığını ekle.
- [x] Kullanıcı adı seçim ekranını kurallarla birlikte (anlık validasyon + banlı liste kontrolü) uygula.
- [x] Profil ve sözleşme onay ekranını (zorunlu/onay kutuları, pazarlama izni) tamamla.
- [x] Firebase Auth, Firestore ve Azure SQL Database senkronizasyonunu (outbox/idempotent) entegre et.
- [x] Claims/policy sürüm değerlerini kayıt sonunda ayarla ve test et.
- [x] Kayıt akışı state machine yapısını (Riverpod StateNotifier) oluştur.
- [x] Pozitif/negatif test senaryolarını widget/integration testleriyle kapsa.

## 2. Login Paneli

- [x] E-posta/kullanıcı adı + parola giriş ekranını Flutter bileşenleriyle uygula.
- [x] MFA/TOTP/Passkey ekranlarını ve backup kod akışını ekle.
- [x] Rate limit, captcha ve hesap kilidi geri bildirimlerini UI içinde göster.
- [x] “Beni hatırla” ve cihaz parmak izi yönetimini Riverpod ile bağla.
- [x] Firestore lastLoginAt güncellemesi ve Azure SQL Database LoginEvents kaydını gerçekleştir.
- [x] Oturum yönetim servislerini (refresh token rotasyonu) Flutter tarafında uygula.
- [x] Login akışı için widget/integration testleri yaz.

## 3. Ana Sayfa (Home Feed)

- [x] Feed UI (takip edilenler, önerilenler, sponsor slotları) bileşenlerini geliştir (segment switch + sponsor vitrin hazır).
- [x] Firestore gerçek zamanlı akışı ve Azure SQL Database candidate set entegrasyonunu bağla (FeedApiConfig + RemoteFeedRepository hazır).
- [x] Sıralama (ranking) sinyallerini ve çeşitlilik kurallarını client tarafına getir (FeedRankingService + çeşitlilik kuralı).
- [x] Sponsorlu içerik etiketlemelerini ve frekans limitlerini UI’da uygula.
- [x] Telemetri event’lerini (scroll, like, share, report) TraceHttpClient üzerinden kaydet.
- [x] Feed performansı için lazy loading/testleri ekle.

## 4. Etiketleme (Hashtag, Mention, Medya Etiketi)

- [x] Caption içinde hashtag/@mention typeahead bileşenlerini geliştir.
- [x] Medya üstü etiketleme (tap to tag) arayüzünü oluştur.
- [x] Etiket onay kuyruğunu (flag’li mod) kullanıcı ayarlarıyla bağla.
- [ ] Engellenen kullanıcı/banlı hashtag kurallarını UI doğrulamalarıyla uygula.
- [ ] İndeks güncellemeleri için gerekli API çağrılarını TraceHttpClient ile çalıştır.
- [ ] İlgili widget/integration testlerini tamamla.

## 5. UI Bileşenleri ve Tema

- [ ] `shared/widgets` ve tema rehberindeki bileşenleri proje geneline entegre et.
- [ ] CgThemeExtension üzerinden koyu/açık tema varyantlarını uygula.
- [ ] Yerelleştirme (TR ve çoklu dil) desteğini UI’da etkinleştir.
- [ ] Erişilebilirlik (A11Y) kriterleri için odak, kontrast ve screen reader etiketlerini doğrula.

## 6. Durum Yönetimi ve DI

- [ ] Her modül için Riverpod provider’larını `features/*/application` altında tanımla.
- [ ] GetIt servis kayıtlarını `core/di/service_locator.dart` içinde tamamla.
- [ ] Mock ve gerçek repository implementasyonlarını UI katmanına bağla.

## 7. Telemetri, Rate Limit ve Güvenlik Entegrasyonları

- [ ] TelemetryService event çağrılarını (kayıt, login, feed, etiketleme) UI aksiyonlarına ekle.
- [ ] TraceHttpClient kullanarak tüm HTTP çağrılarına W3C header propagasyonu uygula.
- [ ] Rate limit uyarıları ve güvenlik mesajlarını (OTP limit, captcha, kilit) UI’da standartlaştır.

## 8. Test Stratejisi

- [ ] Widget testleri: kayıt/login/feed/etiketleme ekranları için pozitif & negatif senaryolar (feed senaryoları tamamlandı).
- [x] Login akışı modern UI ile hizalandı ve widget testleri güncellendi.
- [ ] Integration testleri: Firebase + mock backend senaryoları (happy path & hata durumları).
- [ ] Golden/görsel testler: kritik ekranların tematik doğrulaması.
- [ ] Telemetri ve rate-limit olayları için birim testleri (mock servislerle).

## 9. Dokümantasyon ve İzleme

- [ ] Implementasyon ilerledikçe `uygulama içindekiler.txt` ve ilgili README’leri güncelle.
- [ ] Yeni konfigürasyon değişkenleri için `env/.env.template` ve README yönergelerini eşitle.
- [ ] Telemetri event şeması değişirse `docs/telemetry_events.md` ve redaction rehberini senkronize et.
- [x] App Check test moduna ilişkin yönergeleri README ve `docs/devops/config-management.md` ile hizala.

_TODO listesi güncel tutulacak; tamamlanan maddeler işaretlenecek, yeni ihtiyaçlar ortaya çıktıkça eklemeler yapılacak._
