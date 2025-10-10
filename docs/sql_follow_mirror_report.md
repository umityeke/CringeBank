# SQL Follow Mirror Validation Report

_Durum Tarihi: 8 Ekim 2025_

## Özet

- `dbo.FollowEdge` tablosu ve indeksleri otomatik olarak oluşturuldu (`scripts/setup_follow_edge_table.js`).
- TLS engelleri self-signed sertifika için `SQLSERVER_TRUST_CERT=true` ile aşılarak hedef SQL sunucusuna bağlanıldı.
- `node scripts/dm_follow_consistency.js --check=follow` komutu gerçek veritabanında çalıştırıldı ve JSON raporu üretildi.
- Tablo henüz boş olduğundan 0 satır kontrol edildi; eksik/mismatch kaydı gözlenmedi.
- Follow backfill için `scripts/sql/backfill_follow_edges.js` scripti hazırlandı ve jest testleriyle doğrulandı (henüz canlı veritabanına yazım yapılmadı).
- Flutter istemcisine `MessagingFeatureService` ve `SqlMirrorLatencyMonitor` eklendi; DM ve follow servisleri SQL gateway çağrılarını runtime özellik bayrağıyla tetikleyip Crashlytics üzerinden <200 ms hedefini izleyebiliyor.
- `scripts/sql/run_mirror_validation.js` komutu ile backfill + tutarlılık raporlarını CI/yerel ortamlarda tek adımda çalıştırmak mümkün hale geldi.

## Kurulum Adımları

1. Ortam değişkenlerini (PowerShell) tanımla:

   ```powershell
   Set-Location -Path 'c:\dev\cringebank'
   $env:SQLSERVER_HOST = 'localhost'
   $env:SQLSERVER_USER = 'sa'
   $env:SQLSERVER_PASS = '******'
   $env:SQLSERVER_DB   = 'CringeBank'
   $env:SQLSERVER_ENCRYPT = 'true'
   $env:SQLSERVER_TRUST_CERT = 'true'
   ```

2. Mirror tablosunu oluştur:

   ```powershell
   node .\scripts\setup_follow_edge_table.js
   ```

3. Tabloyu doğrula (opsiyonel):

   ```powershell
   node .\scripts\check_follow_table.js
   ```

4. Backfill scriptini dry-run modunda gözlemle (opsiyonel):

   ```powershell
   node .\scripts\sql\backfill_follow_edges.js --dry-run --limit=10
   ```

   > Gerçek yazım için `--dry-run` bayrağını kaldırıp aynı komutu çalıştırın. `--follower=<uid>` ile belirli kullanıcıyı hedefleyebilirsiniz.

5. Consistency raporunu üret:

   ```powershell
   node .\scripts\dm_follow_consistency.js --check=follow --limit=100 --output=json --silent
   ```

## Rapor Çıktısı (8 Ekim 2025)

```json
{
  "follow": {
    "checked": 0,
    "missingFirestore": [],
    "mismatches": []
  }
}
```

## Gözlemler

- FollowEdge tablosu yeni oluşturulduğu için henüz veri içermez; bu nedenle consistency raporunda satır doğrulanmamıştır.
- TLS sertifikası self-signed olduğundan şimdilik `SQLSERVER_TRUST_CERT=true` bayrağı kullanılmaktadır. Uzun vadede CA imzalı sertifika ile `trustServerCertificate=false` hedeflenmelidir.
- Flutter uygulamasında SQL mirror çift yazımı, `config_messaging/sql_mirror` belgesinden yönetilen bayrakla açılıp kapatılabiliyor; Crashlytics log’ları `sql_mirror_latency` etiketiyle kaydediliyor.
- Latency eşiği aşılırsa (varsayılan 200 ms) Crashlytics non-fatal hata olarak işaretleniyor; eşik `latencyThresholdMs` alanıyla güncellenebilir.

## Sonraki Adımlar

1. **Backfill**: `scripts/sql/backfill_follow_edges.js` scriptini dry-run sonrasında gerçek modda çalıştırarak `dbo.FollowEdge` tablosunu doldur.
2. **Sürekli Senkronizasyon**: Firestore → SQL aynalama kuyruğu (Service Bus/Queue) prod ortamında etkinleştirilmeli; yeni Flutter çift yazımıyla birlikte kuyruk tüketicileri (processor) devreye alınmalı.
3. **Gerçek Zamanlı Okuma**: SQL tabanlı SignalR/WebSocket prototipi hazırlanıp kapasite testleri yapılmalı; Flutter tarafında `sqlReadEnabled` bayrağı aktifleştirildiğinde sadece SQL’den okuma moduna geçilecek.

Bu doküman follow aynası fazının mevcut durumunu özetler ve eksik işleri listeleyerek takibi kolaylaştırır.
