# Azure Managed Identity Onboarding Rehberi

Bu doküman, CringeBank backend API uygulamasının Azure SQL Database ve diğer Azure hizmetlerine **Managed Identity** (MI) kullanarak bağlanması için izlenecek adımları açıklar. Amaç, uygulama kodunda veya konfigürasyon dosyalarında parola tutmadan güvenli bağlantı sağlamaktır.

---

## 1. Ön Koşullar

- Azure aboneliğinde `Contributor` yetkisi (hedef resource group üzerinde).
- Azure CLI 2.30+ veya Azure PowerShell.
- Azure SQL Database (ör. `cringebank-sql`) ve App Service (ör. `cringebank-api-dev`) kaynakları yaratılmış olmalı. `infra/azure/main.bicep` şablonu bu kaynakları otomatik oluşturur.
- Local development için Visual Studio / VS Code'da Azure hesabıyla oturum açtığınızdan emin olun (`az login`).

---

## 2. App Service için System-Assigned Managed Identity

Bicep şablonumuz App Service'e otomatik olarak system-assigned MI tanımlar. Manuel olarak etkinleştirmek gerekiyorsa:

```powershell
az webapp identity assign \
  --resource-group rg-cringebank-backend \
  --name cringebank-api-dev
```

Komut, App Service'in `principalId` ve `tenantId` değerlerini döndürür. Bu kimlik, Azure SQL ve Key Vault için kullanılacaktır.

---

## 3. Azure SQL: Managed Identity Kullanıcısı Oluşturma

1. Azure portal veya `az sql server ad-admin create` ile SQL sunucusuna Azure AD yöneticisi atayın (Bicep parametresi `sqlAdAdminObjectId`).
2. Azure Data Studio / SSMS üzerinden Azure AD yöneticisi hesabıyla veritabanına bağlanın.
3. Aşağıdaki T-SQL komutlarını çalıştırın:

```sql
CREATE USER [cringebank-api-mi] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [cringebank-api-mi];
ALTER ROLE db_datawriter ADD MEMBER [cringebank-api-mi];
```

İhtiyaca göre ek roller (`db_ddladmin`, özel schema izinleri vb.) eklenebilir. Bu kullanıcı adı, App Service MI'nın `principalId` değeriyle eşleştirilir.

---

## 4. Azure SQL Firewall ve Private Erişim

- **Public Network disable**: Bicep, SQL sunucusunda `publicNetworkAccess = Disabled` ayarlar. API'nin erişebilmesi için Private Endpoint veya Virtual Network entegrasyonu gereklidir.
- Eğer hızlı test için public erişim açılması gerekiyorsa:

```powershell
az sql server update \
  --resource-group rg-cringebank-backend \
  --name cringebank-sql \
  --set publicNetworkAccess=Enabled
```

Ardından istemci IP'nizi geçici olarak ekleyebilirsiniz:

```powershell
az sql server firewall-rule create \
  --resource-group rg-cringebank-backend \
  --server cringebank-sql \
  --name AllowMyIP \
  --start-ip-address <IP> \
  --end-ip-address <IP>
```

Üretim ortamında Private Endpoint + VNet bütünleşmesi önerilir.

---

## 5. Key Vault Erişimi

1. `infra/azure/main.bicep` App Service MI'ya Key Vault üzerinde `get/list` secret izinleri tanımlar (`keyVaultAccessForApp`).
2. Ek kullanıcı/grup izinleri lazım olduğunda:

```powershell
az keyvault set-policy \
  --name cringebank-kv-dev \
  --resource-group rg-cringebank-backend \
  --object-id <aad-object-id> \
  --secret-permissions get list set delete
```

3. Uygulama tarafında Key Vault referansları kullanmak için App Service ayarına aşağıdaki formatta değer girin:

```
@Microsoft.KeyVault(SecretUri=https://cringebank-kv-dev.vault.azure.net/secrets/CringeBank-JwtKey/)
```

---

## 6. .NET (C#) Kod Örneği

```csharp
using Azure.Identity;
using Microsoft.Data.SqlClient;

var credential = new DefaultAzureCredential();
var token = await credential.GetTokenAsync(new TokenRequestContext(new[] { "https://database.windows.net/.default" }));

var builder = new SqlConnectionStringBuilder
{
    DataSource = "tcp:cringebank-sql.database.windows.net,1433",
    InitialCatalog = "CringeBank",
    Authentication = SqlAuthenticationMethod.ActiveDirectoryAccessToken
};

await using var connection = new SqlConnection(builder.ConnectionString)
{
    AccessToken = token.Token
};
await connection.OpenAsync();
```

`DefaultAzureCredential`, App Service üzerinde system-assigned MI ile otomatik token alır. Lokal geliştirmede VS/CLI oturumunu kullanır.

---

## 7. Uygulama Konfigürasyonu

- `env/backend.env.template` içindeki `CRINGEBANK__CONNECTIONSTRINGS__SQL` değeri:

```
Server=tcp:cringebank-sql.database.windows.net,1433;Database=CringeBank;Authentication=ActiveDirectoryDefault;Encrypt=True;
```

- App Service üzerinde aynı değeri **Application Settings** bölümüne ekleyin.
- `Jwt:Key`, `ServiceBus` gibi diğer gizli değerler Key Vault üzerinden yönetilmelidir.

---

## 8. Doğrulama Checklist'i

- [ ] App Service MI etkin ve `principalId` kaydedildi.
- [ ] Azure SQL üzerinde MI için kullanıcı oluşturuldu ve gerekli rollere eklendi.
- [ ] SQL firewall/Private Endpoint konfigürasyonu tamamlandı.
- [ ] Key Vault secrets oluşturuldu; App Service uygulama ayarlarında Key Vault referansları tanımlı.
- [ ] Uygulama loglarında `ActiveDirectoryDefault` ile bağlantı hatası görünmüyor.
- [ ] CI/CD pipeline'ı `az sql` ve `az keyvault` komutları için gerekli izinlere sahip.

---

## 9. Faydalı Komutlar

```powershell
# Managed Identity principal ID'sini öğren
az webapp show -g rg-cringebank-backend -n cringebank-api-dev --query identity.principalId -o tsv

# SQL veritabanı rollerini kontrol et
az sql db show --resource-group rg-cringebank-backend --server cringebank-sql --name CringeBank

# App Service ayarlarını listele
az webapp config appsettings list -g rg-cringebank-backend -n cringebank-api-dev

# Key Vault secrets
az keyvault secret list --vault-name cringebank-kv-dev
```

---

Bu rehber, Managed Identity ile parola saklamadan güvenli bağlantı kurmanızı sağlar. Güncel mimari kararları `docs/cringebank_enterprise_architecture.md` dosyasıyla uyumlu tutmayı unutmayın.
