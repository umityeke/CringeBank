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
```

> `SMTP_PASSWORD` alanına Google hesabında iki adımlı doğrulama etkinleştirildikten sonra
> oluşturduğunuz 16 haneli uygulama şifresini yazın. Dosya `.gitignore` tarafından zaten
> dışlandığı için sürüm kontrolüne eklenmez.
>
> **Not:** Gmail ve benzeri sağlayıcılarda SMTP kullanıcı adı çoğunlukla gönderen e-posta adresiyle aynıdır.
> Eğer `SMTP_USER` boş bırakılırsa kod otomatik olarak `SMTP_FROM_EMAIL` değerini kullanır.

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

> **Güvenlik hatırlatması:** `.env` dosyalarını asla kaynağa (git) eklemeyin ve
> yalnızca güvenilir dağıtım kanallarında paylaşın. Çok faktörlü kimlik doğrulaması
> (2FA) ve uygulama şifreleri, Gmail hesabınızın güvenliği için kritik önem taşır.
