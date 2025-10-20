# Backend TODO Listesi

> Bu liste CringeBank sunucu tarafi gereksinimlerini kapsamli sekilde izlemek icin hazirlanmistir. Gorevler tamamlandikca ilgili satirin basindaki kutuyu isaretleyin ve gerekiyorsa kisa bir not ekleyin.

## Takip Kurallari
- [ ] Her gorev icin ilgili kisi/ekip ve hedef tarihini docs/backend_todo.md icinde parantez ile belirtin (ornegin `(Sahip: Ali, Hedef: 2025-11-15)`).
- [ ] Degisen mimari kararlarini docs/cringebank_enterprise_architecture.md dosyasi ile senkron tutun.
- [ ] Kritik degisiklikler icin README_BACKEND.md ve docs/backend_deployment.md dokumanlarini guncellemeyi unutmayin.

-## 1. Ortam ve Altyapi Hazirligi

- [ ] Azure kaynaklari icin IaC (Bicep veya Terraform) paketi yaz (`infra/azure/main.bicep`): Resource Group, Azure SQL, Storage, Service Bus, Key Vault, App Service, Application Insights.
- [x] Lokal gelistirme icin dotnet user-secrets setup betigi ekle (`scripts/setup_dev_backend.ps1`, 2025-10-20).
- [ ] AppSettings konfigurasyonunu iceriklere gore ayrilmis hale getir (Development, Staging, Production) ve kisitli alanlari environment degiskenlerine tasima kilavuzu yaz.
- [ ] Backend icin standardize edilmis `.env` sablonu olustur (`env/backend.env.template`) ve CI pipeline'larina bagla.
- [ ] Azure SQL Managed Identity baglantisi icin dokuman ve onboarding rehberi hazirla (Managed Identity, Key Vault referansi, firewall kurallari).

## 2. Veritabani ve EF Core
- [ ] docs/backend_schema_plan.md dokumanindaki `auth` ve `social` tablolarini EF Core entity ve Fluent konfigurasyonlariyla uygula.
- [ ] Varsayilan roller ve RBAC kayitlari icin veritabani seed mekanizmasi yaz (Migration veya `IDataSeeder`).
- [ ] auth.Users icin stored procedure ile login audit kaydi ekle.
- [ ] Outbox patterni icin `outbox.Events` tablosunu ve EF Core entity'sini olustur.
- [ ] auth, social, chat, wallet alanlarina ait migration paketlerini olustur ve `CringeBank.sln` icinde bagla.
- [ ] Migration'lari otomatik test eden bir `dotnet test` collection (integration) ekle.

## 3. Domain ve Application Katmani
- [ ] CringeBank.Domain icinde value object ve aggregate siniflarini schema planina gore organize et (User, Profile, Post, Conversation, Wallet, Order).
- [ ] CringeBank.Application katmaninda CQRS tabanli command/query handler yapisini finalize et (`MediatR` veya custom pipeline`).
- [ ] Validation katmanini (FluentValidation) kullanarak tum public command/query'ler icin kural setlerini yaz.
- [ ] Domain event'leri tanimla ve Application katmaninda event handler'lari bagla (audit, telemetry, push bildirimleri icin).
- [ ] Use case bazinda DTO ve mapper katmanini (Mapster veya AutoMapper) entegre et.

## 4. API Yuzeyi ve Endpoints
- [ ] AuthController: email/parola girisi, refresh token, magic link, MFA dogrulama endpointlerini yayinla.
- [ ] ProfileController: public profil oku, kendi profilini guncelle, avatar/banner upload secure pre-signed URL donuslerini ekle.
- [ ] FeedController: timeline feed, user feed ve arama endpointleri icin pagination ve filtrelemeyi uygula.
- [ ] ChatController: sohbet olusturma, mesaj gonderme, mesajlari isaretleme endpointleri ve SignalR hub entegrasyonu.
- [ ] WalletController: bakiye goruntule, hareket listesi, escrow islem cagrilari (SQL gateway ile) icin HTTP endpoint adaptoru.
- [ ] AdminController: rol atama, suspend/ban islemleri, sayfalama ve filtreli listeleme.
- [ ] Swagger/OpenAPI dokumantasyonunu tum endpointler icin aciklama ve ornek body ile tamamla.

## 5. Yetkilendirme, Kimlik ve Guvenlik
- [ ] JWT ureteci icin asymmetric anahtar destegini ekle ve anahtar rotasyonu senaryosu hazirla.
- [ ] Refresh tokenlar icin sliding expiration ve revoke mekanizmasini uygula (CringeBank.Application + Infrastructure).
- [ ] RBAC politikasini merkezi belgeye tasiyan `PolicyEvaluator` servisini yaz ve tum controller'lara attribute olarak uygula.
- [ ] Rate limiting (IP + kullanici bazli) icin ASP.NET rate limiting middleware konfigurasyonunu tamamla.
- [ ] Serilog ile guvenlik log'larini (login, logout, policy deny) ayricalikli kategoriye yonlendir.
- [ ] App Check token dogrulamasini backend tarafina ekleyerek Firebase client cagrilarini koru (detaylar icin docs/backend_callable_plan.md).

## 6. Telemetri, Izleme ve Kayit
- [ ] Health check endpointlerini (`/health/live`, `/health/ready`) veri tabani ve harici sistem kontrolleri ile zenginlestir.
- [ ] Serilog'u Seq veya Application Insights sink'i ile entegre et ve minimal runtime konfigurasyonu yaz.
- [ ] OpenTelemetry veya Jaeger icin tracing pipeline'ini ekle.
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
