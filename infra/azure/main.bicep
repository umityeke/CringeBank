targetScope = 'resourceGroup'

@description('Azure bölgesi. Varsayılan olarak hedef resource group lokasyonu kullanılır.')
param location string = resourceGroup().location

@description('Kaynak adlarında kullanılacak önek. Küçük harf, rakam ve tire kullanın (ör. cringebank).')
param namePrefix string

@description('Ortam etiketi (ör. dev, staging, prod).')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('SQL Server yönetici kullanıcı adı (Azure SQL sunucusu oluşturulurken gereklidir).')
param sqlAdministratorLogin string = 'sqladminuser'

@secure()
@description('SQL Server yönetici parolası. Dağıtım sırasında güvenli parametre olarak aktarın.')
param sqlAdministratorPassword string

@description('Azure AD SQL sunucu yöneticisi gösterim adı (Portalda gözükecek).')
param sqlAdAdminLogin string

@description('Azure AD SQL sunucu yöneticisinin Object ID değeri.')
param sqlAdAdminObjectId string

@description('Key Vault erişimi verilecek Azure AD nesne kimlikleri (kullanıcı, grup veya managed identity).')
param keyVaultAccessObjectIds array = []

@description('App Service SKU adı (ör. P1v3, P1v2, S1).')
param appServiceSkuName string = 'P1v2'

@description('App Service plan kapasitesi (instance sayısı).')
param appServiceSkuCapacity int = 1

var normalizedPrefix = toLower(replace(namePrefix, ' ', ''))
var sqlServerName = take('${normalizedPrefix}sql${environment}', 60)
var sqlDatabaseName = 'CringeBank'
var storageAccountName = toLower(replace('${normalizedPrefix}${environment}sa', '-', ''))
var serviceBusNamespaceName = take('${normalizedPrefix}sb${environment}', 50)
var serviceBusQueueName = 'outbox-events'
var keyVaultName = take('${normalizedPrefix}-kv-${environment}', 24)
var appServicePlanName = '${normalizedPrefix}-plan-${environment}'
var appServiceName = '${normalizedPrefix}-api-${environment}'
var appInsightsName = '${normalizedPrefix}-appi-${environment}'

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
  tags: {
    environment: environment
  }
}

resource sqlServerAzureAdAdmin 'Microsoft.Sql/servers/administrators@2022-05-01-preview' = {
  name: 'ActiveDirectory'
  parent: sqlServer
  properties: {
    administratorType: 'ActiveDirectory'
    login: sqlAdAdminLogin
    sid: sqlAdAdminObjectId
    tenantId: subscription().tenantId
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: sqlDatabaseName
  parent: sqlServer
  location: location
  sku: {
    name: 'GP_S_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }
  properties: {
    zoneRedundant: false
    autoPauseDelay: 60
    minCapacity: json('0.5')
  }
  tags: {
    environment: environment
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    accessTier: 'Hot'
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
  tags: {
    environment: environment
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
  }
  tags: {
    environment: environment
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  name: serviceBusQueueName
  parent: serviceBusNamespace
  properties: {
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    lockDuration: 'PT5M'
    enableBatchedOperations: true
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enablePurgeProtection: true
    enableSoftDelete: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
    accessPolicies: [for objectId in keyVaultAccessObjectIds: {
      tenantId: subscription().tenantId
      objectId: objectId
      permissions: {
        secrets: [
          'get'
          'list'
          'set'
          'delete'
        ]
        keys: [
          'get'
          'list'
        ]
      }
    }]
  }
  tags: {
    environment: environment
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServiceSkuName
    capacity: appServiceSkuCapacity
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
  tags: {
    environment: environment
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
  tags: {
    environment: environment
  }
}

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET|8.0'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: toUpper(environment)
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
  tags: {
    environment: environment
  }
}

resource keyVaultAccessForApp 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appService.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

output sqlServerResourceId string = sqlServer.id
output sqlDatabaseResourceId string = sqlDatabase.id
output storageAccountResourceId string = storageAccount.id
output serviceBusNamespaceResourceId string = serviceBusNamespace.id
output serviceBusQueueName string = serviceBusQueueName
output keyVaultName string = keyVault.name
output appServiceName string = appService.name
output appServicePlanName string = appServicePlan.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
