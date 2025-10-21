[CmdletBinding()]
Param(
    [string]$Project = 'backend/src/CringeBank.Api/CringeBank.Api.csproj',
    [string]$SqlConnectionString,
    [string]$JwtKey,
    [switch]$InitOnly
)

$ErrorActionPreference = 'Stop'

function Test-CommandAvailability {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Gerekli arac bulunamadi: $Name"
    }
}

function New-RandomSecret {
    param([int]$Bytes = 64)
    $buffer = New-Object byte[] $Bytes
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    return [Convert]::ToBase64String($buffer)
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

Test-CommandAvailability -Name 'dotnet'

$projectFullPath = Resolve-Path -Path (Join-Path $repoRoot $Project) -ErrorAction Stop

$arguments = @('user-secrets', 'list', '--project', $projectFullPath)
& dotnet @arguments | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'UserSecrets init ediliyor...'
    & dotnet @('user-secrets', 'init', '--project', $projectFullPath)
    if ($LASTEXITCODE -ne 0) {
        throw 'user-secrets init komutu basarisiz oldu.'
    }
}

if ($InitOnly) {
    Write-Host 'InitOnly parametresi verildi, sadece init tamamlandi.'
    return
}

if (-not $SqlConnectionString) {
    $prompt = @()
    $prompt += 'Azure SQL baglanti dizgisini girin (ornegin:'
    $prompt += 'Server=tcp<server-name>.database.windows.net,1433;Database=CringeBank;Encrypt=True;'
    $prompt += 'Authentication=ActiveDirectoryDefault;)'
    $SqlConnectionString = Read-Host ($prompt -join " `n")
    if ([string]::IsNullOrWhiteSpace($SqlConnectionString)) {
        throw 'Azure SQL baglanti dizgisi bos birakilamaz.'
    }
}

if (-not $JwtKey) {
    $JwtKey = New-RandomSecret -Bytes 64
    Write-Host "Jwt anahtari otomatik olusturuldu: $JwtKey"
}

$setArgs = @('user-secrets', 'set', '--project', $projectFullPath, 'ConnectionStrings:Sql', $SqlConnectionString)
& dotnet @$setArgs
if ($LASTEXITCODE -ne 0) {
    throw 'ConnectionStrings:Sql degeri ayarlanamadi.'
}

$setJwtArgs = @('user-secrets', 'set', '--project', $projectFullPath, 'Jwt:Key', $JwtKey)
& dotnet @$setJwtArgs
if ($LASTEXITCODE -ne 0) {
    throw 'Jwt:Key degeri ayarlanamadi.'
}

Write-Host ''
Write-Host 'User secrets guncellendi.'
Write-Host "Proje: $projectFullPath"
Write-Host "ConnectionStrings:Sql = $SqlConnectionString"
Write-Host "Jwt:Key (base64) = $JwtKey"
