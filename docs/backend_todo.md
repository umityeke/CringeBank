# Backend TODO Listesi

> Bu liste CringeBank sunucu tarafi gereksinimlerini kapsamli sekilde izlemek icin hazirlanmistir. Gorevler tamamlandikca ilgili satirin basindaki kutuyu isaretleyin ve gerekiyorsa kisa bir not ekleyin.

## Takip Kurallari
- [ ] Her gorev icin ilgili kisi/ekip ve hedef tarihini docs/backend_todo.md icinde parantez ile belirtin (ornegin `(Sahip: Ali, Hedef: 2025-11-15)`).
- [ ] Degisen mimari kararlarini docs/cringebank_enterprise_architecture.md dosyasi ile senkron tutun.
- [ ] Kritik degisiklikler icin README_BACKEND.md ve docs/backend_deployment.md dokumanlarini guncellemeyi unutmayin.

## Durum Ozeti (20 Ekim 2025)

- Tamamlananlar: Azure IaC paketleri, ortam konfigurasyonlari, Managed Identity rehberi, auth & social EF Core entity/migration setleri ve varsayilan RBAC seed mekanizmasi calisir durumda.
- Guncel odak alanlari `docs/uygulama_icindekiler.txt` icindeki “PROJE TODO DURUM OZETI” ile uyumlu olup; veritabani/EF Core gelistirmeleri, domain & application katmani, API yuzeyi, guvenlik/telemetri, entegrasyonlar ve test/CI kalemleri siradaki sprintlerin kapsamindadir.
- Her yeni gorev girisinde bu dosya ile merkez dokumandaki ozeti birlikte guncelleyerek backlog’un tek kaynaktan gorunmesini saglayin.

## 1. Ortam ve Altyapi Hazirligi

- [x] Azure kaynaklari icin IaC (Bicep veya Terraform) paketi yaz (`infra/azure/main.bicep`, 2025-10-20): Resource Group, Azure SQL, Storage, Service Bus, Key Vault, App Service, Application Insights.
- [x] Lokal gelistirme icin dotnet user-secrets setup betigi ekle (`scripts/setup_dev_backend.ps1`, 2025-10-20).
- [x] AppSettings konfigurasyonunu iceriklere gore ayrilmis hale getir (Development, Staging, Production) ve kisitli alanlari environment degiskenlerine tasima kilavuzu yaz (2025-10-20).
- [x] Backend icin standardize edilmis `.env` sablonu olustur (`env/backend.env.template`, 2025-10-20) ve CI pipeline'larina bagla.
- [x] Azure SQL Managed Identity baglantisi icin dokuman ve onboarding rehberi hazirla (`docs/backend_managed_identity_guide.md`, 2025-10-20).

## 2. Veritabani ve EF Core

- [x] docs/backend_schema_plan.md dokumanindaki `auth` ve `social` tablolarini EF Core entity ve Fluent konfigurasyonlariyla uygula (Tamam: 2025-10-20).
- [x] Varsayilan roller ve RBAC kayitlari icin veritabani seed mekanizmasi yaz (Migration veya `IDataSeeder`) (Tamam: 2025-10-20).
- [x] auth.Users icin stored procedure ile login audit kaydi ekle (Tamam: 2025-10-20).
- [x] Outbox patterni icin `outbox.Events` tablosunu ve EF Core entity'sini olustur (Tamam: 2025-10-20).
- [x] auth, social, chat, wallet alanlarina ait migration paketlerini olustur ve `CringeBank.sln` icinde bagla. (Sahip: Backend Platform, Hedef: 2025-10-22)
- [x] Migration'lari otomatik test eden bir `dotnet test` collection (integration) ekle. (Sahip: Backend Platform, Hedef: 2025-10-22)

## 3. Domain ve Application Katmani

- [x] CringeBank.Domain icinde value object ve aggregate siniflarini schema planina gore organize et (User, Profile, Post, Conversation, Wallet, Order). (Tamam: 2025-10-20)
- [x] CringeBank.Application katmaninda CQRS tabanli command/query handler yapisini finalize et (`MediatR` veya custom pipeline`). (Tamam: 2025-10-20 — Özel komut/sorgu arayüzleri, dispatcher, validation pipeline'ı ve ilk handler seti eklendi.)
- [x] Validation katmanini (FluentValidation) kullanarak tum public command/query'ler icin kural setlerini yaz. (Tamam: 2025-10-20 — Kullanıcı senkronizasyonu ve profil sorgusu validator kuralları genişletildi, xUnit ile doğrulandı.)
- [x] Domain event'leri tanimla ve Application katmaninda event handler'lari bagla (Tamam: 2025-10-20 — User aggregate için domain event seti oluşturuldu, EF SaveChanges sonrası dispatcher tetikleniyor ve outbox tabanlı handler'lar audit/telemetri/push konularını kuyrukluyor).
- [x] Use case bazinda DTO ve mapper katmanini (Mapster veya AutoMapper) entegre et. (Tamam: 2025-10-20 — Mapster tabanlı `IObjectMapper` altyapısı eklendi, User senkronizasyonu DTO’lara otomatik mapleniyor ve unit test ile doğrulandı.)

## 4. API Yuzeyi ve Endpoints

- [x] AuthController: email/parola girisi, refresh token, magic link, MFA dogrulama endpointlerini yayinla. (Tamam: 2025-10-20 — Password login, refresh, magic link ve MFA minimal API endpointleri eklendi; JWT/refresh token akisi üretildi.)
- [x] ProfileController: public profil oku, kendi profilini guncelle, avatar/banner upload secure pre-signed URL donuslerini ekle. (Tamamlandı: 2025-10-21 — Self profil okuma/güncelleme ve SAS tabanlı yükleme uç noktaları eklendi, Azure Blob yapılandırması appsettings altında tanımlandı.)
- [x] FeedController: timeline feed, user feed ve arama endpointleri icin pagination ve filtrelemeyi uygula. (Tamamlandı: 2025-10-21 — Cursor tabanlı timeline/user/search uç noktaları yayınlandı, Azure Storage tabanlı medya bilgileri dahil edildi, RBAC policy ve appsettings güncellendi.)
- [x] ChatController: sohbet olusturma, mesaj gonderme, mesajlari isaretleme endpointleri ve SignalR hub entegrasyonu. (Tamamlandı: 2025-10-21 — Minimal API uç noktaları, CQRS komutları ve SignalR hub yayını eklendi.)
- [x] WalletController: bakiye goruntule, hareket listesi, escrow islem cagrilari (SQL gateway ile) icin HTTP endpoint adaptoru. (Tamamlandı: 2025-10-21 — Minimal API cüzdan uç noktaları, SQL gateway entegrasyonu ve RBAC güncellendi.)
- [x] AdminController: rol atama, suspend/ban islemleri, sayfalama ve filtreli listeleme. (Tamamlandı: 2025-10-21 — Admin kullanıcı listeleme ve rol/durum yönetimi uç noktaları Program.cs içinde uygulandı, CQRS handler'ları çağırıyor ve RBAC policy seti güncellendi.)
- [x] Swagger/OpenAPI dokumantasyonunu tum endpointler icin aciklama ve ornek body ile tamamla. (Tamamlandı: 2025-10-21 — Program.cs üzerindeki minimal API uç noktalarına özet/açıklama, durum kodu üretimleri ve örnek istek/yanıt payload’ları eklendi.)

## 5. Yetkilendirme, Kimlik ve Guvenlik

- [x] JWT ureteci icin asymmetric anahtar destegini ekle ve anahtar rotasyonu senaryosu hazirla. (Tamam: 2025-10-20 — JwtOptions çoklu anahtar desteğine geçirildi, RSA/HMAC imzalama ve ephemeral fallback eklendi.)
- [x] Refresh tokenlar icin sliding expiration ve revoke mekanizmasini uygula (CringeBank.Application + Infrastructure). (Tamam: 2025-10-20 — Sliding pencere JwtOptions:RefreshSlidingMinutes ile tanımlandı, refresh yenileme ve logout komutu/endpointi eklendi.)
- [x] RBAC politikasini merkezi belgeye tasiyan `PolicyEvaluator` servisini yaz ve tum controller'lara attribute olarak uygula. (Tamam: 2025-10-20 — PolicyEvaluator servisi DI ile eklendi, RBAC endpoint filtresi `session.bootstrap` politikasını enforce ediyor; yeni admin rotaları geldikçe policy seti genişletilecek.)
- [x] Rate limiting (IP + kullanici bazli) icin ASP.NET rate limiting middleware konfigurasyonunu tamamla. (Tamamlandı: 2025-10-21 — Token bucket tabanlı küresel hız limiti eklendi, kullanıcı kimliği ve istemci IP'sine göre ayrışıyor, Retry-After başlığı ayarlanıyor.)
- [x] Serilog ile guvenlik log'larini (login, logout, policy deny) ayricalikli kategoriye yonlendir. (Tamamlandı: 2025-10-21 — Login/logout uç noktaları güvenlik loglarını hash'lenmiş kimliklerle yazıyor, PolicyEndpointFilter güvenlik etiketi ekliyor ve Serilog ayrı security-log dosyasına yönlendiriyor.)
- [x] App Check token dogrulamasini backend tarafina ekleyerek Firebase client cagrilarini koru (Tamamlandı: 2025-10-21 — Firebase App Check doğrulayıcı DI'ya alındı, Minimal API grupları filtre ile zorunlu hale getirildi, yapılandırma `Authentication:AppCheck` altında expose edildi.)

## 6. Telemetri, Izleme ve Kayit

- [x] Health check endpointlerini (`/health/live`, `/health/ready`) veri tabani ve harici sistem kontrolleri ile zenginlestir. (Tamamlandı: 2025-10-21 — SQL bağlantısı, Firebase Auth ve Firebase App Check için health check eklendi, `/health/ready` JSON çıktısı durum/kaynak bazında detay üretir.)
- [x] Serilog'u Seq veya Application Insights sink'i ile entegre et ve minimal runtime konfigurasyonu yaz. (Tamamlandı: 2025-10-21 — Seq sink opsiyonel hale getirildi, `Telemetry:Seq` ayarlarıyla etkinleştirilip minimum seviye ve API anahtarı yapılandırılabiliyor.)
- [x] OpenTelemetry veya Jaeger icin tracing pipeline'ini ekle. (Tamamlandı: 2025-10-21 — ASP.NET Core ve HttpClient için OpenTelemetry izleme eklendi, konsol/OTLP exporter konfigüre edilebilir hale getirildi, kaynak meta verileri environment bilgisiyle zenginleştirildi.)
- [ ] Prometheus uyumlu metrik endpointi kur ve temel metrikleri expose et.
- [ ] Error budget ve performans hedefleri icin dokuman hazirla; CI pipeline'ina smoke test raporlamasi ekle.

## 7. Entegrasyonlar ve Harici Sistemler

- [ ] Firebase Auth'tan SQL user senkronizasyonu icin arka plan job'u yaz (user yoksa olustur, profil guncelle).
- [ ] Firestore -> SQL public profil mirror kontrolu icin `functions` paketine bagli reconciliation job'u tasarla.
- [ ] Payment/escrow stored procedure cagrilari icin HTTP -> SQL adapter katmanini test edilebilir hale getir.
- [ ] Bildirim servisi (push/email) icin `notify` domain tablosunu ve event tetikleyicilerini olustur.
- [ ] Telemetry endpointi ile backend loglari arasinda korelasyon (traceId propagation) sagla.

## 8. Test Stratejisi ve Otomasyon

- [ ] Unit testler: Domain ve Application katmani icin kapsama yuzdesi hedefi belirle (>=80%) ve raporlama ekle.
- [ ] Integration testler: WebApplicationFactory kullanarak API entegrasyon testleri yaz, Azure SQL test veritabanina karsi calistir (CI icin ephemeral database stratejisi belirle).
- [ ] Contract testler: Swagger schema'sini kullanarak Pact veya smoke test seti cikart.
- [ ] Load test: k6 veya Azure Load Testing ile temel senaryolar icin script yaz.
- [ ] CI pipeline'inda test dagilimini (unit, integration, load smoke) ayiran job yapisi kur.

## 9. DevOps ve Dagitim

- [ ] GitHub Actions veya Azure DevOps pipeline'i ile build, test, publish adimlarini otomatiklestir.
- [ ] Docker image build pipeline'i icin multi-stage Dockerfile yaz (base SDK + runtime).
- [ ] Production ortamina deploy icin terraform veya bicep senaryosu (App Service + SQL + Key Vault) hazirla.
- [ ] Blue/green veya canary deploy stratejisi icin yol haritasi hazirla.
- [ ] Rollback prosedurunu otomatiklestiren script (migration revert + image rollback) ekle.

## 10. Veri Goc ve Mirror

- [ ] Firestore'daki mevcut verileri SQL'e tasimak icin ETL pipeline'i (scripts/etl_fire_to_sql.ps1) hazirla.
- [ ] Gecici okuma modunda Firestore baglantisini saglayacak fallback stratejisini dokumante et.
- [ ] Wallet ve escrow islemleri icin durum kontrol scriptlerini (consistency checker) guncelle.
- [ ] Snapshot alma/yukleme islemleri icin SQL backup rehberi yaz ve otomasyon ekle.

## 11. Dokumantasyon ve Onboarding

- [ ] README_BACKEND.md uzerinde gelistirme akisini guncelle (setup, test, run, debug adimlari).
- [ ] Yeni gelene onboarding rehberi (docs/backend_onboarding.md) olustur.
- [ ] EF Core tablolarinin ER diyagramini repo icinde `docs/diagrams/backend_schema.drawio` olarak sagla.
- [ ] API kullanimi icin Postman koleksiyonu veya VS Code REST client dosyalari ekle (`docs/api_samples/`).
- [ ] Incident response ve destek rehberini (kiminle iletisime gecilecegi, SLA) yaz.

## 12. Go-Live Check List

- [ ] Production ortaminda health endpointleri ve Swagger erisimi dogrula.
- [ ] JWT anahtarlarinin Key Vault'ta saklandigini kontrol et.
- [ ] Logging ve monitoring alarmlarini (CPU, hata oranlari, gecikme) ayarla.
- [ ] Uygulama ve veritabani backup stratejilerini dokumante et ve otomasyona bagla.
- [ ] Post-deploy smoke test planini olustur ve sorumlularini ata.
