# Firebase Functions Dotenv Yapılandırması

Firebase, Mart 2026'dan itibaren `functions.config()` API'sini sonlandıracağı için
Cloud Functions yapılandırmasını `.env` tabanlı sisteme taşımanız gerekiyor.
Aşağıdaki adımlar, mevcut SMTP ayarlarınızı yeni yönteme geçirmenize yardımcı olur.

## 1. Yerel `.env` dosyasını oluştur

1. `functions` klasöründe bulunan `.env.example` dosyasını kopyalayın:

   ```powershell
   cd functions
   Copy-Item .env.example .env
   ```

2. Oluşan `.env` dosyasını düzenleyip gerçek değerleri girin:

   ```dotenv
   SMTP_FROM_EMAIL=cringeebank@gmail.com
   SMTP_USER=cringeebank@gmail.com
   SMTP_FROM_NAME=CringeBank
   SMTP_PASSWORD=zkys avkf eizv dphm
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=465
   # Opsiyonel gelişmiş ayarlar
   # SMTP_APP_PASSWORD=
   # SMTP_REQUIRE_TLS=true
   # SMTP_DISABLE_TLS_VERIFICATION=false
   ```


> `SMTP_PASSWORD` alanına Google hesabında iki adımlı doğrulama etkinleştirildikten sonra
> oluşturduğunuz 16 haneli uygulama şifresini yazın. Dosya `.gitignore` tarafından zaten
> dışlandığı için sürüm kontrolüne eklenmez.
>
> **Not:** Gmail ve benzeri sağlayıcılarda SMTP kullanıcı adı çoğunlukla gönderen e-posta adresiyle aynıdır.
> Eğer `SMTP_USER` boş bırakılırsa kod otomatik olarak `SMTP_FROM_EMAIL` değerini kullanır.
> `SMTP_REQUIRE_TLS` ve `SMTP_DISABLE_TLS_VERIFICATION` değişkenleri, TLS bağlantı zorunluluğunu
> ve sertifika doğrulamasını özelleştirmenizi sağlar (gelişmiş/sorun giderme senaryoları için).

## 2. Firebase CLI ile dotenv sistemine geçiş

1. Firebase CLI sürümünüzü güncelleyin:

   ```powershell
   npm install -g firebase-tools
   ```

2. Proje kökünde aşağıdaki komutu çalıştırarak eski runtime config verilerini
yedekleyin ve dotenv sistemine taşıyın:

   ```powershell
   firebase functions:config:migrate
   ```

   Bu komut `functions/.env`, `.env.local`, `.env.<projectId>` gibi dosyaları oluşturabilir.
   Var olan `.env` dosyanızla birleştirmeyi unutmayın.
3. İhtiyaç duyduğunuz diğer ortamlar (örn. prod, staging) için
   `functions/.env.prod`, `functions/.env.staging` benzeri dosyalar oluşturabilir,
   CI/CD süreçlerinde bu dosyaları kullanabilirsiniz.

### (Opsiyonel) Eski `functions:config` değerlerini güncelle

Dotenv geçişi tamamlanana kadar legacy runtime config yöntemini kullanmanız gerekiyorsa,
aşağıdaki komutla SMTP ayarlarını Firebase'e yazabilirsiniz:

```powershell
firebase functions:config:set `
   smtp.host="smtp.gmail.com" `
   smtp.port="465" `
   smtp.user="cringeebank@gmail.com" `
   smtp.password="jahi pqcg ugex nbbi" `
   smtp.from_email="cringeebank@gmail.com" `
   smtp.from_name="CringeBank"
```

> Bu komut yalnızca yerel `.env` dosyanızdaki değerlerin aynısını oluşturur ve uzun vadede
> dotenv tabanlı yaklaşımın yerine geçmez. Komutu çalıştırdıktan sonra ilgili fonksiyonları
> yeniden dağıtmayı (`firebase deploy --only functions:sendEmailOtpHttp`) unutmayın.

## 3. Deploy sırasında dotenv dosyalarını kullan

- Yerel geliştirme için `firebase emulators:start` veya `npm run serve` komutları `.env` dosyasını otomatik okur.
- CI/CD ortamında gerekli değişkenleri güvenli şekilde sağlayın. Örnek: GitHub Actions'da
   secrets kullanarak `.env` dosyasını build pipeline'ında oluşturmak.
- Deploy komutu değişmeden devam eder:

   ```powershell
   firebase deploy --only functions
   ```


## 4. Eski `functions.config()` çağrılarını temizle

Kod tarafında `functions.config()` kullanmıyorsanız ek değişiklik gerekmez.
`functions/index.js` dosyasında SMTP ayarları zaten `process.env.*` değişkenlerine
bakacak şekilde tasarlanmıştır. Eğer başka yerlerde `functions.config()` kullanımı
varsa, bunları da aynı şekilde environment değişkenlerine uyarlayın.

---

## Ek: Emülatörlerde güvenli test akışı

Functions Shell veya testler sırasında prod kaynaklarına yazmamak için şu adımları izleyin:

1. **`firebase.json` emülatör bloğu** — Bu repo içinde gerekli port ve servis tanımları aktiftir.
2. **Emülatörleri başlatın** — Prod dışı bir proje kimliğiyle çalıştırın:

    ```powershell
    firebase emulators:start --project demo-cringebank `
       --only functions,firestore,auth,storage,pubsub
    ```

   Emulator UI [http://localhost:4000](http://localhost:4000) adresinde açılır.

3. **SDK'ları emülatöre yönlendirin** — Flutter tarafında `useFirestoreEmulator`, `useAuthEmulator`, `useFunctionsEmulator`, `useStorageEmulator` çağrılarını yapın (Android emülatörü için `10.0.2.2`, web/iOS için `localhost`). Node.js testlerinde ilgili ortam değişkenlerini ayarlayın (`FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST`, vb.).
4. **Prod guard** — `functions/index.js` dosyasında emülatör dışında (yerel Functions Shell vb.) çalışıp prod'a erişmeyi engelleyen koruma bulunur. GCP üzerinde barındırılan ortam otomatik olarak izinlidir; yerelde bilinçli olarak prod'a bağlanmanız gerekirse `ALLOW_PROD=true` değişkenini siz set etmelisiniz.
5. **Komutlarda demo proje kullanın** — Yanlışlıkla prod seçimini engellemek için `--project demo-cringebank` bayrağını veya `firebase use demo-cringebank` komutunu tercih edin.

6. **Flutter entegrasyon testleri** — `integration_test/firebase_emulator_integration_test.dart` senaryoları emülatörle çalıştırmak için PowerShell oturumunda
   `CRINGEBANK_USE_FIREBASE_EMULATOR=true`, `FIREBASE_AUTH_EMULATOR_HOST=localhost:9099` ve `FIRESTORE_EMULATOR_HOST=localhost:8787` değişkenlerini set edin veya `scripts/run_emulator_tests.ps1` scriptini kullanın. Uzaktan (canlı) testler için `scripts/run_remote_tests.ps1` ile
   `CRINGEBANK_RUN_FIREBASE_REMOTE_TESTS=true`, `CRINGEBANK_REMOTE_EMAIL=<test_kullanıcısı>`, `CRINGEBANK_REMOTE_PASSWORD=<şifre>` değişkenlerini sağlayın.

HTTP fonksiyonlarını test etmek için emülatör URL'lerini (`http://127.0.0.1:5001/demo-cringebank/...`) kullanın. Entegre testleri `firebase emulators:exec --project demo-cringebank "npm test"` ile izole şekilde çalıştırabilirsiniz.

---

> **Güvenlik hatırlatması:** `.env` dosyalarını asla kaynağa (git) eklemeyin ve
> yalnızca güvenilir dağıtım kanallarında paylaşın. Çok faktörlü kimlik doğrulaması
> (2FA) ve uygulama şifreleri, Gmail hesabınızın güvenliği için kritik önem taşır.
