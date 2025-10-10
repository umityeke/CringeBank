# SQL Kimlik Eşleşmesi Durum Özeti

## Mevcut Varlıklar

- `backend/scripts/provision_sql.sql` yalnızca veritabanı ve uygulama login/rol tanımlamalarını yapıyor; tablo ya da indeks oluşturulmuyor.
- Cloud Functions tarafında `ensure_user.js`, `search_users.js` ve `follow_preview.js` modülleri MSSQL bağlantısı kuruyor ve `dbo.Users` ile ilişkili prosedürlerin varlığını varsayıyor.
- `backend/scripts/migrations/20251007_01_create_users_table.sql` dbo.Users tablosunu oluşturuyor ve zorunlu sütun kontrollerini içeriyor.
- `backend/scripts/migrations/20251007_02_add_auth_uid_unique_index.sql` AuthUid üstüne filtreli benzersiz indeks tanımlıyor.
- `backend/scripts/stored_procedures/sp_EnsureUser.sql` prosedürü `dbo.sp_EnsureUser` uygulamasını sağlıyor (kilitlemeli güncelleme ve duplicate güvenlikleriyle).
- `backend/scripts/stored_procedures/sp_GetUserProfile.sql` prosedürü `AuthUid` üzerinden kullanıcı profilini okuyor.
- Flutter ve Callable katmanı, kullanıcı belgelerinin tek kaynağının SQL + Firestore backend olacağı şekilde hazır durumda (`ensureSqlUser` callable testi mevcut).
- `scripts/sql/backfill_auth_users.js` betiği Firebase Auth → SQL senkronizasyonu için hazır (dry-run desteği ve batch parametreleri içeriyor).
- `scripts/sql/staging_phase0_check.js` betiği migration dry-run + opsiyonel backfill + auth senkron kontrolünü zincirleyerek standart CI aşamasını sağlıyor (`npm run ci:phase0`).
- `scripts/sql/run_migrations.js` ve `npm run migrate:sql` komutu migration + stored procedure dosyalarını sıralı şekilde uygulayacak şekilde hazır.

## Açık Eksikler

1. **Stored Procedure Testleri:** `dbo.sp_EnsureUser` için unit/integration testleri mevcut değil.

2. **Migration Otomasyonu:** Komut satırı aracı mevcut olsa da CI/CD pipeline'ına entegre edilmesi gerekiyor.

3. **Backfill Doğrulaması:** Backfill betiğinin staging ortamında denenip raporlanması gerekiyor.

## Sonraki Adımlar

1. `dbo.sp_EnsureUser` için Jest/tSQLt testleri yazıp CI'a eklemek.
2. Migration ve stored procedure betiklerini otomatik çalıştıracak bir dağıtım adımı hazırlayıp `npm run migrate:sql` komutunu pipeline'a entegre etmek.
3. Staging ortamında migration + backfill çalıştırılıp, sonuçlar `scripts/sql/verify_auth_uid_roundtrip.js` testi ile doğrulanacak.

Bu belge, Phase 0 çalışmalarına başlamadan önce repo içindeki mevcut durumu referans almak için güncellenecektir.
