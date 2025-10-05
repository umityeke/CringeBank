# Firebase Yeniden Kurulum Planı (Ultra Stabil Sürüm)

Bu belge, mevcut Firebase projesi tamamen temizlendikten sonra Cringe Bankası uygulamasının tüm Firebase servislerini **adım adım**, hataya dayanıklı ve güvenli biçimde yeniden kurmak için hazırlanmıştır. Kullanıcı verileri (Authentication) hala mevcutsa onları koruyacak şekilde ilerlenebilir.

---

## 1. Ön Hazırlık

### 1.1 Araçlar ve Hesaplar

- [ ] `firebase-tools` ≥ 13 ve `gcloud` CLI kurulu
- [ ] `flutterfire_cli` kurulu (`dart pub global activate flutterfire_cli`)
- [ ] Admin yetkili Google hesabı ile giriş yapılmış (`firebase login`, `gcloud auth login`)
- [ ] Doğru proje ID'leri not edildi (eski: `cringe-bank`, yeni: `cringebank-v2` gibi)
- [ ] Varsayılan GCP lokasyonu belirlendi (önerilen: `europe-west1`)

### 1.2 Kaynak Dosyalar

- `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`
- `functions/` klasörü
- Seed scriptleri: `scripts/seed_client.js`, `scripts/seed_store_products.js`

### 1.3 Güvenlik Kontrolleri

- [ ] Prod müşterileri bilgilendirildi, bakım modu aktif
- [ ] Yedekler alındı (Firestore, Storage, Functions config)
- [ ] CI/CD veya otomatik görevler durduruldu

---

## 2. Yeni Firebase Projesi Oluşturma

1. GCP projesi açın:

   ```powershell
   firebase projects:create cringebank-v2 --display-name "Cringe Bankasi"
   gcloud config set project cringebank-v2
   ```

1. CLI bağlama:

   ```powershell
   firebase use --add cringebank-v2
   ```

1. Gerekli API’leri etkinleştirin:

   ```powershell
   gcloud services enable \
     firebase.googleapis.com \
     firestore.googleapis.com \
     storage-component.googleapis.com \
     identitytoolkit.googleapis.com \
     cloudfunctions.googleapis.com \
     pubsub.googleapis.com \
     appdistribution.googleapis.com \
     firebasehosting.googleapis.com
   ```

1. Firestore → Native mode, lokasyon `europe-west1`
1. Storage bucket otomatik açılır (`cringebank-v2.firebasestorage.app`)

> Yeni proje adı/eski projeyi tekrar kullanma durumuna göre komutları adapte edin.

---

## 3. Authentication Yapılandırması

1. Firebase Console → Authentication → Sign-in Methods:
   - Email/Password
   - Google, Apple, Facebook vb (gerekirse)
   - Phone auth gerekiyorsa reCAPTCHA anahtarları
1. Özel domain email şablonları yüklenir (gerekirse)

1. Eski kullanıcı listesi taşınacaksa:

   ```powershell
   gcloud identity toolkit import-users --hash-algo=scrypt --hash-key="<KEY>" --salt-separator="<SEP>" --rounds=8 --memory-cost=14 --project=cringebank-v2 users_export.json
   ```
   > Salt/hash parametreleri eski export’a göre ayarlanmalı.

1. Firebase Console → Users sekmesi ile doğrulama

---

## 4. Firestore Kurulumu

1. Kuralları deploy edin:

   ```powershell
   firebase deploy --only firestore:rules --project cringebank-v2
   ```

1. Indexleri deploy edin:

   ```powershell
   firebase deploy --only firestore:indexes --project cringebank-v2
   ```

1. Zorunlu koleksiyonlar (ilk seed öncesi):
   - `store_wallets`
   - `store_products`
   - `store_orders`
   - `escrows`
   - `users`
   - `follow_edges`
   - `blocks`
1. Gerekli alanlar için TTL/purge politikaları ve composite indexler (bkz. `firestore.indexes.json`)
1. Bakım modunda tüm yazma operasyonları Cloud Functions üzerinden gerçekleşmeli.

---

## 5. Storage Kurulumu

1. Bucket kontrolü:

   ```powershell
   gsutil ls
   ```

1. `storage.rules` deploy:

   ```powershell
   firebase deploy --only storage:rules --project cringebank-v2
   ```

1. Varsayılan klasörler:
   - `avatars/`
   - `products/`
   - `tryon-sessions/`
1. Lifecycle policy (opsiyonel): 180 gün sonra eski dosyaları sil
1. CDN/Download için signed URL uygulaması `functions` içinde var, yetkiler kontrol edilmeli

---

## 6. Cloud Functions

1. `functions` dizininde bağımlılıkları kurun:

   ```powershell
   cd functions
   npm ci
   ```

1. Gerekli çevresel değişkenleri set edin:

   ```powershell
   firebase functions:config:set \
     environment.expose_debug_otp="false" \
     twilio.account_sid="XXX" \
     twilio.auth_token="XXX" \
     twilio.from_number="+10000000000" \
     mail.smtp_host="smtp.example.com" \
     mail.smtp_port="587" \
     mail.username="bot@example.com" \
     mail.password="SECRET" \
     googleapis.credentials="<JSON>"
   ```

   > `.env` gerektiren değerleri Secret Manager’a taşımanız önerilir.

1. `npm run lint` (varsa) ve `npm test` (varsa)

1. Deploy:

   ```powershell
   firebase deploy --only functions --project cringebank-v2
   ```

1. Gerekli bölgeler (`region('europe-west1')`) ile uyumlu olduğundan emin olun.

---

## 7. Cloud Messaging & Notifications

1. Firebase Console → Cloud Messaging → Web push için VAPID key oluşturun.
   - Oluşan anahtarı `firebase_options.dart` içine CLI otomatik yazar.
1. Android için FCM ayarları `android/app/google-services.json` içinde gelecek.
1. iOS/macOS için APNs Key yükleyin ve bundle ID eşleşmesini kontrol edin.
1. Eğer `flutter_local_notifications` kullanıyorsanız, platform-specific init fonksiyonlarını doğrulayın.

---

## 8. Analytics & Crashlytics

1. Firebase Console → Analytics etkinleştirin.
1. Crashlytics için `ios`, `android`, `macos` platformlarında dSYM ve Proguard yapılandırması (gradle skriptlerinde ayarlı).
1. İlk çalıştırmada `Crashlytics.log` ve test crash ile doğrulayın:

   ```dart
   FirebaseCrashlytics.instance.crash();
   ```

---

## 9. Flutter Projesini Yeniden Bağlama

1. Eski konfigürasyon dosyalarını temizleyin:

   ```powershell
   Remove-Item android/app/google-services.json -ErrorAction SilentlyContinue
   Remove-Item ios/Runner/GoogleService-Info.plist -ErrorAction SilentlyContinue
   Remove-Item macos/Runner/GoogleService-Info.plist -ErrorAction SilentlyContinue
   Remove-Item windows/firebase_app_id_file.json -ErrorAction SilentlyContinue
   Remove-Item lib/firebase_options.dart -ErrorAction SilentlyContinue
   Remove-Item flutterfire.json -ErrorAction SilentlyContinue
   ```

1. FlutterFire CLI çalıştırın:

   ```powershell
   flutterfire configure \
     --project=cringebank-v2 \
     --out=lib/firebase_options.dart \
     --platforms=android,ios,macos,web,windows \
     --yes
   ```

1. Üretilen dosyaları kontrol edip git’e ekleyin:
   - `lib/firebase_options.dart`
   - `flutterfire.json`
   - Platform spesifik `GoogleService` dosyaları
1. `firebase_options.dart` içinde storage bucket ve auth domain yeni değerlerle güncellenmiş olmalı.
1. `pubspec.yaml` bağımlılıkları güncel (`firebase_core`, `firebase_auth`, `cloud_firestore`, vb.)

---

## 10. Seed & Test Verisi

1. Seed scriptleri içinde proje ID parametresini yeni proje ile çalıştırın:

   ```powershell
   node .\scripts\seed_store_products.js --project cringebank-v2
   node .\scripts\seed_client.js --project cringebank-v2
   ```

1. Test kullanıcıları oluşturma
1. Platform wallet / admin kullanıcı rolleri ekleme
1. `functions` loglarını izleyin: `firebase functions:log --project cringebank-v2`

---

## 11. Son Kontrol Checklist

- [ ] Flutter uygulaması tüm platformlarda açıldı (`flutter run -d windows`, `-d chrome`, `-d android`)
- [ ] Email/Password ile giriş-çıkış testi yapıldı
- [ ] Firestore CRUD akışları problemsiz
- [ ] Cloud Functions loglarında hata yok
- [ ] Storage upload/download çalışıyor
- [ ] Bildirim gönderimi test edildi (push/try-on)
- [ ] Crashlytics test crash raporu düştü
- [ ] Analytics dashboard veri almaya başladı

---

## 12. Otomasyon & İzleme

- GitHub Actions veya benzeri CI'da `firebase deploy` adımları güncellendi
- `scripts/firebase_reset.ps1` DryRun / Execute modlarıyla kullanılabilir
- GCP Monitoring → Log bazlı uyarılar (Functions hata oranı, Firestore kota kullanımı)
- Firebase Usage dashboards düzenli kontrol

---

## 13. Bakım Modundan Çıkış

1. Bakım banner'larını kaldırın
2. Kullanıcılara bilgi verin (Discord, mail vb.)
3. Uygulama mağazalarında gerekiyorsa yeni sürüm yayınlayın
4. İlk 24 saat logları yakından izleyin

---

Bu plan tamamlandığında Cringe Bankası'nın Firebase altyapısı sıfırdan, stabil ve güvenli şekilde yeniden kurulmuş olacaktır. Her adımda `DryRun` ile doğrulama yapmayı ve kritik silme işlemlerinde manuel onaya dikkat etmeyi unutmayın.
