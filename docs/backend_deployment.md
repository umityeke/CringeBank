# CringeBank Backend Deployment Playbook

## 1. Ön Koşullar

- .NET 9 SDK
- Azure CLI ve Azure aboneliğine erişim
- Azure SQL Database (serverless veya managed instance)
- Azure Key Vault (secret yönetimi)
- Azure App Service veya Azure Container Apps (API barındırma)
- Uygulamanın çalışacağı ortam için domain + TLS sertifikası

## 2. Veritabanı Kurulumu

1. IaC ile dağıtım (önerilen)

```powershell
az deployment group create `
  --resource-group rg-cringebank-backend `
  --template-file infra/azure/main.bicep `
  --parameters namePrefix=cringebank environment=dev `
  --parameters sqlAdministratorPassword="<GüçlüParola>" `
  --parameters sqlAdAdminLogin="CringeBank Admin" sqlAdAdminObjectId="<AAD ObjectId>"
```

2. Manuel kurulum tercih ederseniz kaynak grubu ve Azure SQL sunucusunu oluşturun (Managed Identity etkin):

```powershell
az group create -n rg-cringebank-backend -l westeurope
az sql server create -g rg-cringebank-backend -n cringebank-sql --enable-public-network false --identity assigned
az sql db create -g rg-cringebank-backend -s cringebank-sql -n CringeBank --service-objective HS_Gen5_2 --auto-pause-delay 60
```

3. Azure AD yönetici kullanıcısını atayın ve uygulama Managed Identity'sini yetkilendirin:

```powershell
az sql server ad-admin create -g rg-cringebank-backend -s cringebank-sql -u "CringeBank Admin" -i <AAD ObjectId>
```

4. Azure Data Studio veya SSMS üzerinden Managed Identity için veritabanı kullanıcısı oluşturun:

```sql
CREATE USER [cringebank-api-mi] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [cringebank-api-mi];
ALTER ROLE db_datawriter ADD MEMBER [cringebank-api-mi];
```

> Bağlantılar AAD token'ları ile sağlanır. Uygulama tarafında `Authentication=ActiveDirectoryDefault` içeren connection string kullanın.

## 3. Konfigürasyon Yönetimi

### User Secrets (Geliştirme)

```powershell
cd backend/src/CringeBank.Api

dotnet user-secrets init

dotnet user-secrets set "ConnectionStrings:Sql" "Server=tcp:<sql-server-name>.database.windows.net,1433;Database=CringeBank;Authentication=ActiveDirectoryDefault;Encrypt=True;"

dotnet user-secrets set "Jwt:Key" "<64+ karakterlik yeni bir anahtar>"
```

### Ortam Değişkenleri (Üretim)

Aşağıdaki değişkenler uygulama sürecine enjekte edilmelidir:

- `CRINGEBANK__CONNECTIONSTRINGS__SQL`
- `CRINGEBANK__JWT__KEY`
- `ASPNETCORE_ENVIRONMENT=Production`

> Örnek değerler için `env/backend.env.template` dosyasını referans alın. Dosyayı kopyalayıp gizli anahtarları doldurun ve CI/CD pipeline'ında güvenli şekilde yükleyin.

Container örneği:

```yaml
services:
  api:
    image: ghcr.io/umityeke/cringebank-api:latest
    environment:
      CRINGEBANK__CONNECTIONSTRINGS__SQL: "Server=tcp:<sql-server-name>.database.windows.net,1433;Database=CringeBank;Authentication=ActiveDirectoryManagedIdentity;Encrypt=True;"
      CRINGEBANK__JWT__KEY: "<64+ karakterlik anahtar>"
      ASPNETCORE_ENVIRONMENT: "Production"
    ports:
      - "5000:8080"
```

### Konfigürasyon katmanları

- `appsettings.json` ortak varsayılanları içerir (loglama, JWT issuer/audience vb.).
- `appsettings.Development.json`, `appsettings.Staging.json`, `appsettings.Production.json` ortam bazlı ayarları override eder.
- `ConnectionStrings:Sql` ve `Jwt:Key` gibi gizli değerler JSON dosyalarında tutulmaz; bunları user-secrets, App Service Application Settings veya Key Vault referansları ile sağlayın.
- Managed Identity ile Azure SQL ve Key Vault bağlantısını yapılandırmak için `docs/backend_managed_identity_guide.md` rehberini izleyin.

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

## 6. Blue/Green Dağıtım Stratejisi

Blue/green yaklaşımında yeni sürüm staging slotuna alınır, doğrulamalar tamamlandıktan sonra production ile swap edilir:

1. Yeni container imajını GHCR üzerinde yayınlayın (`ghcr.io/umityeke/cringebank-api:<build-id>`).
2. Staging slotunun container imajını güncelleyin ve warmup/smoke testlerini çalıştırın.
3. `scripts/azure_appservice_slot_swap.ps1` betiği ile staging slotunu production ile değiştirin.
4. Swap sonrası `/health/ready` ve uçtan uca smoke testleri çalıştırarak metrikleri izleyin.

> Azure CLI oturumu açık olduğunda aşağıdaki komut staging → production swap işlemini gerçekleştirir:
>
> ```powershell
> ./scripts/azure_appservice_slot_swap.ps1 `
>   -SubscriptionId <subscription-id> `
>   -ResourceGroup rg-cringebank-backend `
>   -AppServiceName cringebank-api `
>   -SourceSlot staging `
>   -TargetSlot production `
>   -WarmupUrl "https://cringebank-api-staging.azurewebsites.net/health/ready"
> ```
>
> Warmup isteği başarısız olursa betik swap işlemine devam eder ancak log çıktısında uyarı üretir. Swap sonrasında üretim trafiği üzerinde ek doğrulamalar yapmayı unutmayın.

## 7. Operasyonel İzleme

- `GET /health/live` ⇒ liveness
- `GET /health/ready` ⇒ readiness + DB erişimi
- Serilog log dosyaları `logs/api-log-*.txt` altında tutulur. Rotasyonun sorunsuz çalıştığını takip edin.
- Önemli hatalar için Serilog'u ek sinklere (Seq, Application Insights) yönlendirin.

## 8. Güvenlik Kontrolleri

- Azure AD tabanlı kimlik doğrulama, MFA zorunluluğu
- Managed Identity ve rol bazlı erişim (db_datareader/db_datawriter)
- Firewall kuralları veya Private Endpoint ile erişimi kısıtlayın
- TLS sertifikası ile HTTPS trafik sağlayın
- JWT anahtarını düzenli aralıklarla yenileyin
- Migration yetkisini belirli servis hesaplarına sınırlandırın

## 9. Sürüm Yükseltme Adımları

1. `dotnet ef migrations add <Name>` (geliştirme)
2. Staging ortamında `dotnet ef database update`
3. CI pipeline ile otomatik testler
4. Production'a geçiş öncesi yedeği alın
5. `dotnet ef database update` (Production)
6. Yayınlanan API'yı yeniden başlatın

## 10. Geri Dönüş Planı

- Migration öncesi DB yedeklemesi
- `dotnet ef database update <öncekiMigration>` ile rollback
- Log dosyalarına göre hata analizi

Ek olarak aşağıdaki betik swap + imaj geri alma + isteğe bağlı migration rollback adımlarını tek komutta çalıştırır:

```powershell
./scripts/rollback_backend_deploy.ps1 `
  -SubscriptionId <subscription-id> `
  -ResourceGroup rg-cringebank-backend `
  -AppServiceName cringebank-api `
  -RollbackTag <stable-tag> `
  -SqlConnectionString "Server=tcp:<sql-server>.database.windows.net,1433;Database=CringeBank;Authentication=ActiveDirectoryDefault;Encrypt=True;" `
  -TargetMigration <öncekiMigration>
```

- `RollbackTag` staging slotuna atanacak kararlı container etiketidir (örn. `stable` veya son başarılı build numarası).
- `SqlConnectionString` ve `TargetMigration` parametreleri veritabanını belirtilen migration seviyesine çeker; migration revert gerekmiyorsa bu değerleri boş bırakın.
- Betik swap işlemini staging → production yönünde gerçekleştirir; swap sonrasında smoke testleri manuel olarak tetikleyip telemetriyi takip edin.

---

Bu doküman, proje canlıya alınırken takip edilmesi gereken standartları özetler. Ek gereksinimler için güvenlik ekibi ve operasyon ekibiyle koordinasyon sağlayın.
