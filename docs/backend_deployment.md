# CringeBank Backend Deployment Playbook

## 1. Ön Koşullar

- .NET 9 SDK
- SQL Server 2019+ (Managed Instance, Azure SQL veya container)
- Azure Key Vault / Docker secrets (opsiyonel fakat önerilir)
- Uygulamanın çalışacağı ortam için domain + TLS sertifikası

## 2. Veritabanı Kurulumu

1. SQL sunucusunda `CringeBank` isminde veritabanı oluşturun.
2. Uygulama için güçlü bir parola seçerek `sqladmin` login ve kullanıcıyı tanımlayın:

```sql
CREATE LOGIN sqladmin WITH PASSWORD = '<GüçlüParola>', CHECK_POLICY = ON;
GO
IF DB_ID('CringeBank') IS NULL CREATE DATABASE CringeBank;
GO
USE CringeBank;
GO
CREATE USER sqladmin FOR LOGIN sqladmin;
ALTER ROLE db_owner ADD MEMBER sqladmin;
GO
ALTER DATABASE CringeBank SET READ_COMMITTED_SNAPSHOT ON;
GO
```

> Parolayı saklamak için Key Vault veya gizli değişken yöneticisi kullanın. Script'i gerektiğinde `IF NOT EXISTS` kontrolleriyle zenginleştirebilirsiniz.

## 3. Konfigürasyon Yönetimi

### User Secrets (Geliştirme)

```powershell
cd backend/src/CringeBank.Api

dotnet user-secrets init

dotnet user-secrets set "ConnectionStrings:Sql" "Server=<sunucu>;Database=CringeBank;User Id=sqladmin;Password=<GüçlüParola>;Encrypt=True;TrustServerCertificate=True;"

dotnet user-secrets set "Jwt:Key" "<64+ karakterlik yeni bir anahtar>"
```

### Ortam Değişkenleri (Üretim)

Aşağıdaki değişkenler uygulama sürecine enjekte edilmelidir:

- `CRINGEBANK__CONNECTIONSTRINGS__SQL`
- `CRINGEBANK__JWT__KEY`
- `ASPNETCORE_ENVIRONMENT=Production`

Container örneği:

```yaml
services:
  api:
    image: ghcr.io/umityeke/cringebank-api:latest
    environment:
      CRINGEBANK__CONNECTIONSTRINGS__SQL: "Server=<host>;Database=CringeBank;User Id=sqladmin;Password=<GüçlüParola>;Encrypt=True;TrustServerCertificate=True;"
      CRINGEBANK__JWT__KEY: "<64+ karakterlik anahtar>"
      ASPNETCORE_ENVIRONMENT: "Production"
    ports:
      - "5000:8080"
```

## 4. Build ve Migration

```powershell
cd backend

dotnet restore

dotnet build CringeBank.sln -c Release

dotnet ef database update --project src/CringeBank.Infrastructure/CringeBank.Infrastructure.csproj -- --environment Production
```

> Migration komutu üretim ortamına karşı çalıştırılmadan önce bağlantı bilgisinin doğru olduğundan emin olun.

## 5. Uygulama Yaygınlaştırma

1. `dotnet publish src/CringeBank.Api/CringeBank.Api.csproj -c Release -o out`
2. Yayınlanan çıktı içindeki `appsettings.Production.json` dosyasını gerektiğinde düzenleyin (CORS vb.).
3. Reverse-proxy (NGINX/IIS) üzerinden HTTPS yönlendirmesi yapılandırın.

## 6. Operasyonel İzleme

- `GET /health/live` ⇒ liveness
- `GET /health/ready` ⇒ readiness + DB erişimi
- Serilog log dosyaları `logs/api-log-*.txt` altında tutulur. Rotasyonun sorunsuz çalıştığını takip edin.
- Önemli hatalar için Serilog'u ek sinklere (Seq, Application Insights) yönlendirin.

## 7. Güvenlik Kontrolleri

- Güçlü parola & MFA zorunluluğu
- `sa` hesabını devre dışı bırakın
- Firewall ile veritabanını sadece uygulama katmanına açın
- TLS sertifikası ile HTTPS trafik sağlayın
- JWT anahtarını düzenli aralıklarla yenileyin
- Migration yetkisini belirli servis hesabıyla sınırlandırın

## 8. Sürüm Yükseltme Adımları

1. `dotnet ef migrations add <Name>` (geliştirme)
2. Staging ortamında `dotnet ef database update`
3. CI pipeline ile otomatik testler
4. Production'a geçiş öncesi yedeği alın
5. `dotnet ef database update` (Production)
6. Yayınlanan API'yı yeniden başlatın

## 9. Geri Dönüş Planı

- Migration öncesi DB yedeklemesi
- `dotnet ef database update <öncekiMigration>` ile rollback
- Log dosyalarına göre hata analizi

---

Bu doküman, proje canlıya alınırken takip edilmesi gereken standartları özetler. Ek gereksinimler için güvenlik ekibi ve operasyon ekibiyle koordinasyon sağlayın.
