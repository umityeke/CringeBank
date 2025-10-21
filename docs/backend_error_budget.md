# Backend Hata Bütçesi ve Performans Hedefleri

Bu doküman, CringeBank backend servislerinin işletim sırasında uyması gereken servis seviyesi hedeflerini (SLO) ve hata bütçesi yönetimini tanımlar. Ayrıca, hataların hızlıca görünür kılınması ve CI pipeline'ında smoke test raporlamasının nasıl yapılacağını açıklar.

## 1. Servis Seviyesi Hedefleri

| Kategori             | Hedef                         | Ölçüm Metodu                             | Açıklama |
|----------------------|-------------------------------|-------------------------------------------|----------|
| Kullanılabilirlik    | Aylık %99.5 SLO             | `/health/ready` endpointi uptime ölçümü  | App Service Availability + Prometheus `http_server_duration_seconds_count` ölçüleri kullanılarak hesaplanır. |
| Yanıt Süresi         | P95 ≤ 500 ms (API)            | Prometheus/OTel `http.server.duration` histogramı | UI kritik rotalar (login, feed, wallet) ayrı ayrı izlenir. |
| Hata Oranı           | P95 hata oranı ≤ %1           | `http.server.request_count` + durum kodu label'ı | 5xx + 429 istekleri hata olarak kabul edilir. |
| Arka Plan İşleri     | İş gecikmesi ≤ 2 dakika       | Hangfire/Cloud Task metric'leri (cron job) | Kullanıcı senkronizasyon ve outbox tüketici işler için geçerlidir. |

## 2. Hata Bütçesi

- **Hata bütçesi** = `(1 - SLO) * toplam süre`. %99.5 aylık SLO için aylık toplam 21.6 dakika kesintiye tolerans vardır.
- Bütçe tüketimi Prometheus'ta `availability:error_budget_consumed_total` metriği ile tutulur. Cron job her 5 dakikada bir `uptime` değerlerini okur ve kalan bütçeyi hesaplar.
- Bütçe tüketimi:
  - %50 üzeri: Ürün ekipleriyle paylaşılır, yeni özellik release'leri kısıtlanmaz ancak gözlem artar.
  - %75 üzeri: Yeni özellik release'leri dondurulur, fokus istikrar/onarım tasklarına kaydırılır.
  - %100: Incident açılır, kök neden analizi (RCA) istenir ve SLA ihlali raporlanır.

## 3. Performans ve Alarm Eşikleri

| Metrik                         | Uyarı Eşiği           | Kritik Eşik        | Alarm Kanalları |
|--------------------------------|-----------------------|--------------------|-----------------|
| `http.server.duration` (P95)   | 450 ms                | 600 ms             | PagerDuty, Slack `#backend-alerts` |
| `http.server.errors` oranı     | %0.8                  | %1.5               | PagerDuty |
| `sql_connection_pool_size`     | %80 doluluk           | %95 doluluk        | Slack |
| `queue.outbox_backlog_total`   | 100 ileti             | 250 ileti          | Slack + e-posta |

## 4. İzleme ve Korelasyon

- OpenTelemetry trace-id request başlığı (`traceparent`) uygulamanın tüm katmanlarında zorunludur.
- Serilog loglarında `TraceId` alanı zorunlu; Application Insights ve Seq sink'leri bu alanı indexler.
- Prometheus scrape'leri `deployment.environment` label'ına göre ayrıştırılır (Development, Staging, Production).

## 5. CI Pipeline Smoke Test Raporlaması

- GitHub Actions pipeline'ı `dotnet build` ve `dotnet test` ardından `scripts/smoke_tests.ps1` betiğini çalıştırır.
- Smoke betiği, in-memory test host üzerinden kritik rotaları (`/`, `/health/ready`, `/api/session/bootstrap` için yetkisiz istek) HTTP GET ile tetikler.
- Başarısızlık durumunda pipeline kırılır, hata raporu GitHub Actions konsoluna yazılır.

## 6. Operasyonel Aksiyonlar

1. Hata bütçesi tüketim raporu haftalık olarak `docs/operations/hata_butcesi_raporu.md` içinde güncellenecek.
2. Incident sonrası RCA için `docs/operations/incident_templates/rca_template.md` kullanılacak.
3. SLA ihlali gerçekleştiğinde `DEPLOYMENT_SUMMARY.md` dosyasında ilgili bölüm güncellenecek.

## 7. Referanslar

- [backend_todo.md](backend_todo.md)
- [backend_deployment.md](backend_deployment.md)
- [cringebank_enterprise_architecture.md](cringebank_enterprise_architecture.md)
