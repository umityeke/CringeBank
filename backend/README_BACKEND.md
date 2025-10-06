# CringeBank Backend (.NET 8 + MSSQL)

## Hızlı Başlangıç

1. SQL Server örneğini ayağa kaldırın (lokalde Docker kullanılabilir `docker compose up -d`).
2. Uygulamanın bağlantı bilgisini **User Secrets** veya ortam değişkeni üzerinden tanımlayın.

```powershell
dotnet user-secrets init --project src/CringeBank.Api/CringeBank.Api.csproj
dotnet user-secrets set "ConnectionStrings:Sql" "Server=<sunucu>;Database=CringeBank;User Id=sqladmin;Password=<güçlü-şifre>;Encrypt=True;TrustServerCertificate=True;"
```

> Alternatif olarak, CI/CD ya da container senaryolarında `CRINGEBANK__CONNECTIONSTRINGS__SQL` ortam değişkenini kullanabilirsiniz.

## Uygulama Ayarları

`src/CringeBank.Api/appsettings.Development.json`

```json
{
  "ConnectionStrings": {
    "Sql": ""
  },
  "Jwt": {
    "Issuer": "cringebank",
    "Audience": "cringebank.app",
    "Key": "CHANGE_ME_SUPER_LONG_SECRET",
    "AccessMinutes": 15,
    "RefreshDays": 30
  },
  "Swagger": { "Enabled": true }
}
```

`appsettings.Production.json` dosyası varsayılan olarak boş connection string ve dosya tabanlı Serilog loglamasıyla gelir. Üretimde değerler kullanıcı gizleri veya ortam değişkenlerinden besleneceği için dosyayı yalnızca CORS gibi davranışsal ayarları değiştirmek için düzenleyin.

## EF Core Migration Komutları

```bash
dotnet tool install --global dotnet-ef
cd backend/src/CringeBank.Infrastructure
dotnet ef migrations add Init
dotnet ef database update
```

## Uygulamayı Çalıştırma

```bash
cd backend/src/CringeBank.Api
dotnet run
```

Swagger arayüzü: <https://localhost:5001/swagger>

Üretime hazırlık, migration ve operasyon adımları için `docs/backend_deployment.md` dokümanına bakın.

## Proje Yapısı

- **CringeBank.Api** — Controllers, SignalR Hubs, Swagger
- **CringeBank.Application** — Use case'ler, DTO'lar, validator'lar
- **CringeBank.Domain** — Entity'ler, enum'lar, value object'ler
- **CringeBank.Infrastructure** — DbContext, migrations, repository implementasyonları, outbox
- **CringeBank.Common** — Hata tipleri, Result wrapper'ları, sabitler
- **CringeBank.Tests.Unit / Integration** — Birim ve entegrasyon testleri

## Komutlar

```bash
dotnet test
dotnet format
```

## SQL Başlangıç Script'i

Docker konteyneri veya yeni bir sunucu hazırlarken aşağıdaki script'i kendi parola politikanıza göre güncelleyip çalıştırabilirsiniz (SSMS veya `sqlcmd`):

```sql
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'sqladmin')
BEGIN
  CREATE LOGIN sqladmin WITH PASSWORD = '<GüçlüBirParolaGiriniz>', CHECK_POLICY = ON;
END
GO
IF DB_ID('CringeBank') IS NULL CREATE DATABASE CringeBank;
GO
USE CringeBank;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'sqladmin')
BEGIN
  CREATE USER sqladmin FOR LOGIN sqladmin;
  ALTER ROLE db_owner ADD MEMBER sqladmin;
END
GO
ALTER DATABASE CringeBank SET READ_COMMITTED_SNAPSHOT ON;
GO
```

## Paket Referansları (önerilen)

- `Microsoft.EntityFrameworkCore.SqlServer`
- `Microsoft.EntityFrameworkCore.Tools`
- `Microsoft.EntityFrameworkCore.Relational`
- `FluentValidation`
- `Serilog.AspNetCore`
- `Swashbuckle.AspNetCore`
- `Microsoft.AspNetCore.SignalR`

## Flutter Entegrasyonu

- Flutter tarafında sadece `BASE_URL`'i yeni API'ye yönlendirin (`http://localhost:5001`).
- Firestore kullanan servisler HTTP isteklerine evrilecek; yeni DTO'lar bu backend'den dönecek JSON'a göre güncellenecek.
- Realtime bildirimlerde SignalR client veya WebSocket tercih edilecek; event sözleşmeleri backend tarafından sağlanacak.
