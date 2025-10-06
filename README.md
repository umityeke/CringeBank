# Cringe Bankası

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

## Windows Firebase SDK Yönetimi

- GitHub dosya boyutu limitine takılmamak ve gizli anahtarları paylaşmamak için `windows/firebase_sdk/` ve `windows/tools/` klasörleri depoya dahil edilmez ( `.gitignore` içerisinde).
- Windows derlemesi yapmak isteyen geliştiriciler, [Firebase C++ SDK](https://firebase.google.com/download/cpp) paketini indirip `windows/firebase_sdk/` dizinine çıkarmalıdır. ZİP arşivi repo dışında saklanmalıdır.
- `firebase_app_id_file.json` dosyası da aynı sebeple depoda yoktur; FlutterFire CLI ile yeniden üretilebilir:

```powershell
flutterfire configure --platforms windows
```

- Bu dosyalar lokal ortamda oluşturulduktan sonra `git status` çıktısında görünmemelidir. Görünüyorsa `.gitignore` kurallarının doğru uygulandığından emin olun.

## Faydalı Kaynaklar

- [Firebase kullanıcı senkronizasyonu rollout kılavuzu](docs/user_sync_rollout.md)
- [CringeStore backend implementasyonu](docs/CRINGESTORE_IMPLEMENTATION.md)
- [Firebase SSOT mimarisi](docs/cringe_entry_share_type_migration.md)


