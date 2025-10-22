param(
    [Parameter(Mandatory = $true)] [string] $SubscriptionId,
    [Parameter(Mandatory = $true)] [string] $ResourceGroup,
    [Parameter(Mandatory = $true)] [string] $AppServiceName,
    [string] $StableSlot = "staging",
    [string] $LiveSlot = "production",
    [string] $ContainerImage = "ghcr.io/umityeke/cringebank-api",
    [string] $RollbackTag,
    [string] $SqlConnectionString,
    [string] $TargetMigration,
    [string] $InfrastructureProject = "backend/src/CringeBank.Infrastructure/CringeBank.Infrastructure.csproj",
    [string] $StartupProject = "backend/src/CringeBank.Api/CringeBank.Api.csproj"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) bulunamadi. Lutfen Azure CLI kurulu oldugundan emin olun.'
}

az account set --subscription $SubscriptionId | Out-Null

if ($RollbackTag) {
    $image = "${ContainerImage}:$RollbackTag"
    Write-Host "${StableSlot} slotu icin container imaji $image olarak ayarlaniyor..."
    az webapp config container set `
        --name $AppServiceName `
        --resource-group $ResourceGroup `
        --slot $StableSlot `
        --docker-custom-image-name $image | Out-Null
}

Write-Host "${StableSlot} slotu yeniden aktif hale getiriliyor..."
az webapp deployment slot swap `
    --name $AppServiceName `
    --resource-group $ResourceGroup `
    --slot $StableSlot `
    --target-slot $LiveSlot | Out-Null

if ($SqlConnectionString -and $TargetMigration) {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw '.NET SDK (dotnet) bulunamadi. Lutfen .NET 9 SDK kurulu oldugundan emin olun.'
    }

    Write-Host "Veritabani $TargetMigration migration seviyesine geri aliniyor..."
    dotnet ef database update $TargetMigration `
        --project $InfrastructureProject `
        --startup-project $StartupProject `
        --connection "$SqlConnectionString"
}

Write-Host 'Rollback islemleri tamamlandi.'
