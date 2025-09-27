# Cringe Bankası

Flutter ile geliştirilmiş bu proje, `cringe_entries` koleksiyonundan gerçek zamanlı verileri çeken kurumsal seviyede bir akış servisi içerir. Bu döngüyü güçlendirmek için Firestore zaman aşımı yönetimi, kalıcı önbellek, telemetri ve indeks yapılandırmaları güncellendi.

## Özellik Özeti

- Firestore `.snapshots()` akışında zaman aşımı 30 saniyeye çıkarıldı; ilk snapshot için daha geniş tolerans sağlar.
- `SharedPreferences` tabanlı TTL önbelleği sayesinde geçici kopmalarda veriler anında gösterilmeye devam eder.
- `_handleEnterpriseError` telemetri logları üretir, UI için durum/hint iletimi sağlar ve TimeoutException sayılarını izler.
- `firestore.indexes.json` dosyası `createdAt` alanı için sıralı indeks içerir.

## Önbellek Davranışı

- Önbellek anahtarı: `enterprise_cringe_entries_cache_v1`
- TTL: 5 dakika. Süresi dolan veriler otomatik temizlenir.
- Test veya manuel kullanım için `CringeEntryService.primeCacheForTesting` / `getCachedEntriesForTesting` yardımcıları sağlandı.

## Telemetri ve UI İpuçları

- `CringeEntryService.streamStatus`, `streamHint` ve `timeoutExceptionCount` `ValueListenable` olarak dışa açılır.
- Timeout durumları `cringe_entries_stream_timeout` eventiyle Firebase Analytics’e raporlanır.
- UI, `streamHint` üzerinden “bağlantı yavaş” gibi mesajlar gösterebilir.

## Testler

Yeni önbellek davranışını doğrulamak için aşağıdaki testi çalıştırın:

```powershell
Set-Location 'c:/Users/Ümit YEKE/CRINGE-BANKASI-2'
flutter test test/services/cringe_entry_service_test.dart
```

## Firestore Yapılandırması

- `firestore.rules` dosyasında `cringe_entries` için okuma erişimi oturum açmış kullanıcılarla sınırlandırılmıştır.
- `firestore.indexes.json` dosyası `createdAt` alanı için zorunlu indeks tanımını içerir. Değişiklikleri dağıtmak için:

```powershell
Set-Location 'c:/Users/Ümit YEKE/CRINGE-BANKASI-2'
firebase deploy --only firestore:indexes,firestore:rules
```

## Faydalı Kaynaklar

- [Flutter Firestore Stream Docs](https://firebase.google.com/docs/firestore/query-data/listen)
- [Firebase Analytics Custom Events](https://firebase.google.com/docs/analytics/events)
