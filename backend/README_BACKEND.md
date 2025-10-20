# CringeBank Backend (.NET 8 + Azure SQL)

## Hızlı Başlangıç

1. Azure CLI ile tenants hesabınıza giriş yapın ve aboneliği seçin:

```powershell
az login
az account set --subscription "<Azure Subscription GUID>"
```

1. Azure SQL Database için bağlantı dizgesini **User Secrets** altında saklayın. Managed Identity/Azure AD ile bağlanacaksanız örnek dizge şu şekilde olabilir:

```powershell
dotnet user-secrets init --project src/CringeBank.Api/CringeBank.Api.csproj
dotnet user-secrets set "ConnectionStrings:Sql" "Server=tcp:<sql-server-name>.database.windows.net,1433;Database=CringeBank;Authentication=ActiveDirectoryDefault;Encrypt=True;"
```

> Üretim ve CI/CD ortamlarında `CRINGEBANK__CONNECTIONSTRINGS__SQL` değerini Azure Key Vault referansı ya da App Service konfigurasyonu üzerinden sağlayın. Kullanıcı adı/parola yerine Azure AD kimlik doğrulaması tercih edilir.

Yerel geliştirme için bu adımları otomatikleştirmek isterseniz `scripts/setup_dev_backend.ps1` betiğini çağırabilirsiniz. Betik, Azure SQL bağlantı dizgesini ve JWT anahtarını sorup `dotnet user-secrets` altında saklar.

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

## Azure SQL Provisyonu

Kaynaklar Infrastructure as Code (Bicep/Terraform) ile tanımlanmalıdır. Örnek bir dağıtım senaryosu:

1. Kaynak grubu ve Azure SQL sunucusu oluşturun (Managed Identity aktif):

```powershell
az group create -n rg-cringebank-backend -l westeurope
az sql server create -g rg-cringebank-backend -n cringebank-sql --enable-public-network false --identity assigned
az sql db create -g rg-cringebank-backend -s cringebank-sql -n CringeBank --service-objective HS_Gen5_2 --auto-pause-delay 60
```

1. Azure AD yönetici ve uygulama Managed Identity'sini yetkilendirin:

```powershell
az sql server ad-admin create -g rg-cringebank-backend -s cringebank-sql -u "CringeBank Admin" -i <AAD ObjectId>
```

1. SSMS/Azure Data Studio içerisinden Managed Identity için kullanıcı oluşturun:

```sql
CREATE USER [cringebank-api-mi] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [cringebank-api-mi];
ALTER ROLE db_datawriter ADD MEMBER [cringebank-api-mi];
```

Outbox, change tracking veya ek şema güncellemeleri `db/schema` klasöründeki script'ler üzerinden yönetilir.

## Realtime Mirror Dağıtımı

Realtime Mirror tablolarını ve saklı yordamlarını kurmak için `backend/scripts` klasöründeki paketleri kullanabilirsiniz:

```powershell
# SQL kimliği ile örnek
cd backend/scripts
./deploy_realtime_mirror.ps1 -Server localhost,1433 -Database CringeBank -Username sa

# Windows kimliği (AAD/Integrated) örneği
cd backend/scripts
./deploy_realtime_mirror.ps1 -Server sql.mycorp.net -Database CringeBank -UseIntegratedSecurity
```

Betik, `deploy_realtime_mirror.sqlcmd` dosyasını sırasıyla çalıştırarak migration ve saklı yordam paketini uygular. `sqlcmd` aracının yüklü olduğundan emin olun (<https://learn.microsoft.com/sql/tools/sqlcmd-utility>).

SQL tarafı ayarlandıktan sonra örnek DM/follow verilerini oluşturmak için Functions paketindeki seed betiğini kullanabilirsiniz:

```powershell
cd functions
npm run mirror:seed -- --dry-run   # sadece log
npm run mirror:seed                # SQL tablo ve SP’lere yazar
```

Betiğin varsayılan fixture dosyası `functions/scripts/fixtures/realtime_mirror_seed.json` konumundadır; senaryoları burada güncelleyebilirsiniz.

Firestore ile SQL mirror eşleşmelerini gözden geçirmek için `scripts` paketindeki kontrol betiğini kullanabilirsiniz:

```powershell
cd scripts
npm run mirror:consistency -- --limit=25 --check=messages
```

Komut, Firestore belgeleri ile SQL tabloları arasındaki farkları tablo olarak raporlar (`--output=json` ile JSON dönebilir).

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
