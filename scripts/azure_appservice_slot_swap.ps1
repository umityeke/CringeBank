param(
    [Parameter(Mandatory = $true)] [string] $SubscriptionId,
    [Parameter(Mandatory = $true)] [string] $ResourceGroup,
    [Parameter(Mandatory = $true)] [string] $AppServiceName,
    [string] $SourceSlot = "staging",
    [string] $TargetSlot = "production",
    [string] $WarmupUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) bulunamadi. Lutfen Azure CLI kurulu oldugundan emin olun.'
}

az account set --subscription $SubscriptionId | Out-Null

if ($WarmupUrl) {
    Write-Host "${SourceSlot} slotu icin warmup istegi gonderiliyor: $WarmupUrl"
    try {
        Invoke-WebRequest -Uri $WarmupUrl -UseBasicParsing -TimeoutSec 30 | Out-Null
    }
    catch {
        Write-Warning "Warmup istegi basarisiz oldu: $($_.Exception.Message)"
    }
}

Write-Host "${SourceSlot} -> ${TargetSlot} slot swap islemi baslatiliyor..."
az webapp deployment slot swap `
    --name $AppServiceName `
    --resource-group $ResourceGroup `
    --slot $SourceSlot `
    --target-slot $TargetSlot | Out-Null

Write-Host 'Slot swap tamamlandi.'
