# 🔄 Firebase Kullanıcı Senkronizasyonu Rollout Kılavuzu

Bu doküman, Cringe Bankası projelerinde yeni **Firebase ↔️ Backend SSOT (Single Source of Truth)** senkronizasyon altyapısını üretime taşımak ve işletmek için gereken adımları özetler. Aşağıdaki talimatlar, hem .NET API tarafında yapılan değişiklikleri hem de Firestore/Cloud Functions güncellemelerini kapsar.

---

## 1. Mimari Özeti

| Katman | Bileşen | Açıklama |
| --- | --- | --- |
| Backend (.NET) | `FirebaseUserProfileFactory`, `UserSynchronizationService` | JWT doğrulaması sırasında Firebase ID token’ından profil üretir, MSSQL `Users` tablosu ile senkronlar. |
| Firebase Functions | `syncUserClaimsOnUserWrite`, `refreshUserClaims` | Firestore `users/{uid}` dokümanındaki durum/rol değişikliklerini custom claim’lere aktarır, `claimsVersion` değerini yönetir. |
| Firestore Rules | `ensureActiveAndFreshClaims()` | Write işlemleri öncesinde kullanıcı claim’lerinin güncel ve `status == active` olduğunu doğrular. |
| Storage Rules | Aynı kontrol | Medya yükleme/silme işlemleri için de claim tazeliği ve `active` status zorunlu. |

> **claimsVersion**: Kullanıcı claim’leri ve tablo kaydı arasında sürüm eşlemesi sağlar. Firebase token’ı bu sürümden küçükse, Firestore/Storage yazma yetkileri reddedilir.

---

## 2. Konfigürasyon

### 2.1 Backend (`appsettings` veya ortam değişkenleri)

| Ayar Anahtarı | Varsayılan | Açıklama |
| --- | --- | --- |
| `Authentication:Firebase:ProjectId` | _zorunlu_ | Firebase projesi. Env var karşılığı `CRINGEBANK__AUTHENTICATION__FIREBASE__PROJECTID`. |
| `Authentication:Firebase:RequireEmailVerified` | `true` | Token doğrulamasında `email_verified` zorunlu. |
| `Authentication:Firebase:CheckRevoked` | `true` | Firebase Admin SDK revocation kontrolü. |
| `Authentication:Firebase:MinimumClaimsVersion` | `1` | Eski tokenların reddedileceği minimum sürüm. |
| `Authentication:Firebase:TokenClockSkew` | `00:05:00` | Maksimum token sapması. |

> Üretim ortamında bu değerleri **Secret Manager / Key Vault** üzerinden set edin.

```powershell
# Örnek: Windows üretim host’unda environment set
setx CRINGEBANK__AUTHENTICATION__FIREBASE__PROJECTID "cringebank-prod"
setx CRINGEBANK__AUTHENTICATION__FIREBASE__CHECKREVOKED "true"
setx CRINGEBANK__AUTHENTICATION__FIREBASE__REQUIREEMAILVERIFIED "true"
setx CRINGEBANK__AUTHENTICATION__FIREBASE__MINIMUMCLAIMSVERSION "1"
```

### 2.2 Firebase Functions konfigürasyonu

Yeni fonksiyonlar ek bir ortam değişkeni gerektirmez. `firebase functions:config:get` çıktısının deploy öncesi yüklendiğinden emin olun.

---

## 3. Rollout Sırası

1. **Veritabanı Hazırlığı**  

   ```powershell
   cd backend
   dotnet ef database update --project src/CringeBank.Infrastructure
   ```

   `AddUsers` migrasyonu ile `Users` tablosu oluşturulur.

2. **Backend Deploy**  
   - Build/test: `dotnet build` & `dotnet test`
   - API deploy pipeline’ını çalıştır.

3. **Cloud Functions**  

   ```powershell
   cd functions
   npm ci
   npm test
   firebase deploy --only functions:syncUserClaimsOnUserWrite,functions:refreshUserClaims
   ```


4. **Firestore & Storage Rules**  

   ```powershell
   firebase deploy --only firestore:rules,storage:rules
   ```


5. **İlk Senkronizasyon**  
   - Firebase Console’dan kritik kullanıcılar için custom claim snapshot alın.
   - Admin hesabıyla aşağıdaki callable’ı tetikleyerek güncel claim’leri rebuild edin:

     ```javascript
     // Firebase Functions HTTPS callable örneği
     const callable = httpsCallable(functions, 'refreshUserClaims');
     await callable({ uid: '<USER_UID>' });
     ```

6. **Token Yenileme**  
   - Mobil/web istemcilerinin yeniden oturum açmasını zorunlu kılın (force sign-out).  
   - Minimum token sürümünü (`MinimumClaimsVersion`) artırdıysanız, deploy sonrası 15 dakika bekledikten sonra eski token’lar otomatik düşecektir.

7. **İzleme**  
   - Functions log’larında `User claims synchronized` mesajlarını takip edin.
   - API loglarında `claims_version` uyumsuzluğu uyarılarını izleyin.

---

## 4. Veri Sözleşmesi

### 4.1 SQL `Users` Tablosu

| Alan | Tip | Açıklama |
| --- | --- | --- |
| `FirebaseUid` | `nvarchar(128)` | Primary lookup; unique index. |
| `Email` | `nvarchar(256)` | Firestore + token referansı. |
| `ClaimsVersion` | `int` | Token/claim senkronizasyon sürümü. |
| `Status` | `int` (`UserStatus`) | `Active`, `Disabled`, `Banned`, `Deleted`. |
| `IsDisabled` | `bit` | Firebase Account disable flag snapshot’ı. |
| `LastSyncedAtUtc` | `datetimeoffset` | Backend senkron zaman damgası. |
| `LastSeenAppVersion` | `nvarchar(32)` | İstemcinin son gönderdiği sürüm. |

### 4.2 Firestore `users/{uid}` Dokümanı

Yeni zorunlu alanlar:

```json
{
  "status": "active",
  "claimsVersion": 3,
  "claimsLastSyncedAt": Timestamp,
  "emailVerified": true,
  "isDisabled": false,
  "disabledAtUtc": null,
  "deletedAtUtc": null
}
```

> Kullanıcıların kendi profillerini güncellerken bu alanlara dokunmasına Firestore rules izin vermez.

---

## 5. Operasyonel Notlar

- **Hata Kurtarma:** `syncUserClaimsOnUserWrite` fonksiyonu auth kaydı silinmiş kullanıcıları loglar; Firestore dokümanını kaldırmanız gerekir.
- **Yüksek Trafik:** Fonksiyon tek doküman değişikliğinde çalışır; toplu rol değişimlerinde `WriteBatch` kullanmayın çünkü her doküman için ayrı tetiklenecektir.
- **Moderasyon Akışı:** Moderatör/administrator claim’leri sadece Firestore dokümanındaki `role`/`roles` alanları ve boolean bayraklardan türetilir.

---

## 6. Sık Kullanılan Komutlar

```powershell
# Tek kullanıcı için claims refresh (superadmin hesabıyla)
firebase functions:shell
# shell içinde:
refreshUserClaims({ uid: 'UID123' })

# Toplu backend doğrulama
cd backend
 dotnet build
 dotnet test

# Functions lint/test (opsiyonel)
cd functions
 npm run lint
 npm test
```

---

## 7. Checklist

- [ ] SQL migrasyonu uygulandı (`Users` tablosu mevcut).
- [ ] Backend deploy edildi ve health check başarılı.
- [ ] `syncUserClaimsOnUserWrite` fonksiyonu deploy edildi.
- [ ] Firestore & Storage kuralları güncel.
- [ ] Minimum token sürümü (`MinimumClaimsVersion`) güncellendi ve duyuruldu.
- [ ] Kritik kullanıcılar için `refreshUserClaims` çağrıldı.
- [ ] İstemciler yeniden oturum açtı.
- [ ] Loglar hatasız.

---

Rollout tamamlandığında Firestore dokümanları, Firebase custom claim’leri ve SQL tablosu arasında tam senkronizasyon sağlanır. Bu altyapı sayesinde, kullanıcı statüsü/rolleri tek kaynaktan yönetilir ve istemci yazma operasyonları kimlik doğrulama katmanında proaktif şekilde denetlenir.
