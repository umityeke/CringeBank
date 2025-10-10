# SQL Kullanıcı Senkronizasyon Planı

## Amaç
- Firebase Auth ile kimliği doğrulanan her kullanıcıyı MSSQL `Users` tablosunda tekilleştirmek.
- Firestore `users/{uid}` belgesini yalnızca backend (Cloud Function) üzerinden oluşturmak ve güncellemek.
- Flutter istemcisinin kayıt sırasında yalnızca yeni callable fonksiyon üzerinden veri göndermesi, doğrudan Firestore yazmaması.

## Mimari Akış
1. Flutter `UserService.register` başarılı olduğunda `ensureSqlUser` callable fonksiyonunu çağırır.
2. Callable fonksiyon:
   - App Check + Auth doğrular.
   - MSSQL `dbo.sp_EnsureUser` prosedürü ile `(auth_uid, email, username, display_name)` değerlerini kaydeder veya mevcut kaydı döndürür.
   - Firestore `users/{uid}` belgesini admin SDK ile günceller (owner read, public cache yazımı backend tarafından yapılır).
   - İstemciye `sqlUserId`, `username`, `flags` vb. meta döner.
3. Flutter tarafı dönen veriyi local modele işler, gerekirse `UserService` cache'ine yazar.

## Stored Procedure Taslağı `dbo.sp_EnsureUser`
- **Girdiler:**

  - `@AuthUid NVARCHAR(64)` (unique)
  - `@Email NVARCHAR(256)` (opsiyonel)
  - `@Username NVARCHAR(64)`
  - `@DisplayName NVARCHAR(128)` (opsiyonel)
- **Çıkışlar:**

  - `@UserId INT` (OUTPUT)
  - `@Created BIT`
- **Davranış:**

  1. `Users` tablosunda `auth_uid = @AuthUid` kaydı varsa güncellenmiş alanları merge eder, `@Created = 0`.
  2. Yoksa yeni kayıt oluşturur, `@Created = 1`.
  3. Uniq constraint (auth_uid UNIQUE) ihlali durumunda tekrar select yapıp döndürür.

```sql
CREATE OR ALTER PROCEDURE dbo.sp_EnsureUser
  @AuthUid NVARCHAR(64),
  @Email NVARCHAR(256) = NULL,
  @Username NVARCHAR(64),
  @DisplayName NVARCHAR(128) = NULL,
  @UserId INT OUTPUT,
  @Created BIT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @ExistingId INT;

  SELECT TOP (1)
    @ExistingId = Id
  FROM dbo.Users WITH (UPDLOCK, HOLDLOCK)
  WHERE AuthUid = @AuthUid;

  IF @ExistingId IS NOT NULL
  BEGIN
    UPDATE dbo.Users
    SET
      Email = COALESCE(@Email, Email),
      Username = COALESCE(NULLIF(@Username, ''), Username),
      DisplayName = COALESCE(NULLIF(@DisplayName, ''), DisplayName),
      UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @ExistingId;

    SET @UserId = @ExistingId;
    SET @Created = 0;
    RETURN;
  END;

  INSERT INTO dbo.Users (AuthUid, Email, Username, DisplayName, CreatedAt, UpdatedAt)
  VALUES (@AuthUid, @Email, @Username, COALESCE(NULLIF(@DisplayName, ''), @Username), SYSUTCDATETIME(), SYSUTCDATETIME());

  SET @UserId = SCOPE_IDENTITY();
  SET @Created = 1;
END;
```

## Firestore Yazımı

- Cloud Function `admin.firestore()` ile `users/{uid}` belgesini minimal alanlarla günceller:
  - `uid`, `sqlUserId`, `username`, `displayName`, `email`, `createdAt`, `updatedAtUtc`.
- Kurallar gereği istemciler yalnızca okur; backend `system_writer` token'ı ile public cache koleksiyonlarını da güncelleyebilir.

## Flutter İntegrasyonu

- `UserService.register` içinde `_saveUserData` çağrısı kaldırılacak.
- Yeni metot: `_ensureServerUser(User user)` → callable’a gidip dönen veriyi `User` modeline uygular.
- `loadUserData` / `getUserById` geçici olarak Firestore dokümanını okumaya devam eder; uzun vadede SQL API kullanılacak.

## Doğrulama

- Cloud Function için unit test (Jest) yazılacak: mevcut kullanıcı ve yeni kullanıcı senaryoları.
- Flutter tarafında integration test: register → callable → local cache.
- Deployment öncesi staging ortamında migration betiği çalıştırılıp rollback planı doğrulanacak.
