# Firebase Sıfırlama ve Yeniden Kurulum Rehberi

> Bu rehber, mevcut Firebase projesini tamamen sıfırlayıp yeni bir proje kurarken izlemeniz gereken adımları anlatır. Amaç, üretim ortamını güvenli biçimde boşaltmak, yeni projeyi eksiksiz oluşturmak ve Flutter istemcisini tekrar yapılandırmaktır.

## Hızlı Başlangıç

> ⚠️ Bu adımlar, üretim ortamında geri dönüşü olmayan işlemler içerir. Komutları çalıştırmadan önce yedek aldığınızdan emin olun.

```powershell
cd C:\dev\cringebank
.\scripts\firebase_reset.ps1 -NewProjectId cringebank-v2 -SourceProjectId cringe-bank -DryRun
```

- Komutların gerçekten çalışması için `-Execute` ekleyin; veri silme istiyorsanız ayrıca `-ForcePurge` kullanın.
- Tam akış örneği:

   ```powershell
   .\scripts\firebase_reset.ps1 -NewProjectId cringebank-v2 -BackupBucket gs://cringe-bank-backup -SourceProjectId cringe-bank -ForcePurge -Execute
   ```

- Script kullanılmadığında aynı komutlar bu rehberin ilerleyen bölümlerinde manuel olarak da listelenmiştir.

## 0.1 Manuel Silme Öncesi Kontroller

- `firebase --version`, `gcloud --version`, `gsutil --version` çıktılarının alınabildiğini doğrulayın.
- `firebase login` ile yetkili hesabınızla giriş yapın; mevcut oturumu `firebase login:list` ile teyit edin.
- `gcloud auth login` ve `gcloud config set project <mevcut-proje>` komutlarıyla çalışma projesini netleştirin.
- Silinecek proje ID'sinin gerçekten amaçlanan proje olduğundan emin olun; `firebase projects:list` ve `gcloud projects list` ile doğrulama yapın.
- Force purge çalıştırmadan önce Firestore, Storage ve Authentication verilerinin yedeğini aldığınıza emin olun (bkz. Bölüm 1).

## 0. Önkoşullar

- `firebase-tools` CLI v13+ ve `gcloud` SDK kurulu olmalı.
- Proje sahibi yetkilerine sahip bir Google hesabıyla oturum açın.
- Yerel `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules` ve `functions/` kodu güncel olmalı.
- Tüm komutları **PowerShell** üzerinden çalıştırabilirsiniz. Windows dışı kullanıcılar için bash eşdeğerleri parantez içinde verilmiştir.

## 1. Tam Yedek Alın (Opsiyonel ama önerilir)

1. **Firestore**

   ```powershell
   $bucket="gs://cringe-bank-backup"
   gcloud config set project cringe-bank
   gcloud firestore export $bucket --collection-ids store_products,store_wallets,admins,orders,escrows
   ```

2. **Storage**

   ```powershell
   gsutil -m cp -r gs://cringe-bank.firebasestorage.app ./backups/storage
   ```

3. **Authentication**

   ```powershell
   gcloud auth login
   gcloud identity toolkit export-users --project=cringe-bank --out=./backups/auth_users.json
   ```

4. **Functions yapılandırması**

   ```powershell
   firebase functions:config:get > ./backups/functions_env.json
   ```

> Not: Eğer yeni projeye temiz başlayacaksanız, yedekleri almak yerine sadece log amaçlı tutabilirsiniz.

## 2. Uygulamayı Bakım Moduna Alın

- `lib/bootstrap.dart` veya benzeri bir giriş noktasında bakım ekranı gösterecek bir bayrak kullanın.
- Cloud Functions tarafında kritik aksiyonları (örn. escrow release) kilitleyin.
- Üretim kullanıcılarını bilgilendirin.

## 3. Eski Firebase Projesini Temizleyin

Devam etmeden önce `firebase login:list` çıktısında doğru hesabı, `firebase use` komutuyla da doğru projeyi gördüğünüzden emin olun.

### Seçenek A – Yeni Projeye Geçiş (Önerilen)

1. [Firebase Console](https://console.firebase.google.com/) üzerinden yeni bir proje oluşturun (örn. `cringebank-v2`).
2. `firebase projects:create cringebank-v2` komutuyla CLI tarafında da kaydedin.
3. Yeni proje hazır olana kadar eski projenizi koruyun; böylece rollback mümkündür.

### Seçenek B – Mevcut Projeyi Sıfırlama

> Dikkat: Bu işlemler kalıcıdır, geri dönüş yoktur.

```powershell
# Firestore koleksiyonlarını sil
firebase firestore:delete --all-collections --project cringe-bank --force

# Storage bucket'ını boşalt
gsutil -m rm -r gs://cringe-bank.firebasestorage.app/**

# Authentication kullanıcılarını kaldır (kota limitli olabilir)
firebase auth:delete --project cringe-bank --force
```

## 4. Yeni Firebase Projesini Kurun

1. **Projeyi oluşturun**

   ```powershell
   firebase projects:create cringebank-v2 --display-name "Cringe Bankasi"
   firebase use --add cringebank-v2
   ```

2. **Gerekli servisleri etkinleştirin**

   ```powershell
   gcloud services enable firestore.googleapis.com \
     firebase.googleapis.com \
     storage-component.googleapis.com \
     identitytoolkit.googleapis.com \
     cloudfunctions.googleapis.com \
     pubsub.googleapis.com \
     appdistribution.googleapis.com \
     firebasehosting.googleapis.com
   ```

3. **Firestore modunu seçin**: Firestore → Native mode.
4. **Storage bucket**: Varsayılan bucket otomatik açılır (ör. `cringebank-v2.firebasestorage.app`).
5. **Authentication sağlayıcıları**: Email/Password + gerekiyorsa OAuth sağlayıcıları etkinleştirin.
6. **Cloud Messaging** için VAPID key üretin (Web push gerekiyorsa).

## 5. Platform Uygulamalarını Yeniden Kaydet

Her platform için yeni bir Firebase App oluşturun ve konfigürasyon dosyalarını kaydedin.

| Platform | Yapılacaklar |
|----------|--------------|
| Android  | `com.example.cringeBankasi` paket adıyla app oluşturun, `google-services.json` indirip `android/app/` klasörüne koyun. |
| iOS/macOS| Bundle ID `com.example.cringeBankasi`. `GoogleService-Info.plist` indirip `ios/Runner/` ve `macos/Runner/` içine kopyalayın. |
| Web     | Barındırma domaini ayarlayın; `firebase-messaging-sw.js` gerekirse güncelleyin. |
| Windows | FlutterFire CLI ile otomatik taşınır. |

> Paket adlarında değişiklik gerekiyorsa Flutter projesini de güncelleyin.

## 6. Flutter Projesini Yeniden Yapılandırın

1. **Eski konfigürasyon dosyalarını temizleyin**

   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `macos/Runner/GoogleService-Info.plist`
   - `windows/firebase_app_id_file.json` (varsa)
   - `lib/firebase_options.dart`
   - `flutterfire.json`

2. **FlutterFire CLI çalıştırın**

   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure --project=cringebank-v2 --out=lib/firebase_options.dart --platforms=android,ios,macos,web,windows
   ```

3. **CLI çıktılarını doğrulayın**

   - `flutterfire.json` güncellensin.
   - Her platformun `GoogleService` dosyaları yerlerine kopyalansın.

4. **Çevresel Değişkenler**

   - `.env` veya `--dart-define` ile kullandığınız API anahtarlarını doğrulayın.

## 7. Cloud Functions ve Rules Yeniden Dağıtımı

1. `firebase use cringebank-v2`
2. Bağımlılıkları kurun:

   ```powershell
   cd functions
   npm ci
   ```

3. Çevresel değişkenleri geri yükleyin:

   ```powershell
   firebase functions:config:set (Get-Content ..\backups\functions_env.json | ConvertFrom-Json | ConvertTo-Json -Compress)
   ```

   > Alternatif: JSON dosyasını manuel düzenleyip `firebase functions:config:set key=value` şeklinde girin.

4. Deploy edin:

   ```powershell
   npm run lint  # varsa
   firebase deploy --only functions
   ```

5. Firestore güvenlik kuralları ve indexler:

   ```powershell
   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes
   firebase deploy --only storage:rules
   ```

## 8. Seed Verilerini Yeniden Yükleyin

- `scripts/seed_client.js` ve `scripts/seed_store_products.js` dosyalarını güncel project ID ile çalıştırın:

  ```powershell
  node .\scripts\seed_store_products.js --project cringebank-v2
  node .\scripts\seed_client.js --project cringebank-v2
  ```

- `functions/` tarafındaki özellikler için gerekli test kullanıcılarını ekleyin.

## 9. Doğrulama Kontrol Listesi

- [ ] Flutter uygulaması `flutter run -d windows` ile açılıyor mu?
- [ ] Firebase Authentication ile giriş yapılabiliyor mu?
- [ ] Firestore yazma/okuma akışları çalışıyor mu?
- [ ] Cloud Functions loglarında hata yok mu?
- [ ] Storage yükleme/indirme test edildi mi?
- [ ] Crashlytics, Analytics ve Messaging etkin mi?

## 10. Eski Projeyi Kapatma

- Yeni proje kararlı çalışmaya başladıktan sonra eski projeyi silin veya yalnızca okuma moduna alın.
- `firebase projects:list` ile gereksiz projeleri temizleyin.

## 11. Versiyon Kontrol ve Otomasyon

1. Bu rehberi güncel tutmak için `docs/firebase_reset_guide.md` dosyasını versiyon kontrolüne ekleyin.
2. Script otomasyonu için `scripts/firebase_reset.ps1` şablonunu kullanın (aşağıya bakın).
3. CI/CD pipeline'ınıza `firebase deploy` adımlarını ekleyin.

## 12. PowerShell Otomasyon Şablonu

`scripts/firebase_reset.ps1` içinde kullanabileceğiniz basit bir iskelet:

```powershell
param (
  [Parameter(Mandatory=$true)][string]$NewProjectId,
  [string]$BackupBucket = "",
  [switch]$PurgeCurrentProject
)

Write-Host "==> Firebase reset başlıyor: $NewProjectId" -ForegroundColor Cyan

if ($BackupBucket) {
  Write-Host "Firestore yedeği alınıyor..."
  gcloud firestore export $BackupBucket
}

if ($PurgeCurrentProject) {
  Write-Host "Mevcut projedeki tüm koleksiyonlar siliniyor..."
  firebase firestore:delete --all-collections --force
}

Write-Host "Yeni proje aktarımı için flutterfire configure çalıştırmayı unutmayın."
```

## 13. Sonuç

Bu adımlar tamamlandığında, Firebase altyapınız sıfırlanmış ve “Cringe Bankası” uygulaması temiz bir projeyle çalışıyor olmalıdır. Her adım sonrasında logları kontrol etmeyi ve gerekirse geri dönüş planını hazırda tutmayı unutmayın.
