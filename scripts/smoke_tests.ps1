param(
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

Write-Host "[Smoke] Backend smoke testleri çalıştırılıyor..."

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Split-Path -Parent $scriptRoot
$testProject = Join-Path $repoRoot "backend/tests/CringeBank.Tests.Unit/CringeBank.Tests.Unit.csproj"

if (-not (Test-Path $testProject)) {
    throw "Smoke test projesi bulunamadı: $testProject"
}

$resultsDirectory = Join-Path $repoRoot "artifacts/test-results"
if (-not (Test-Path $resultsDirectory)) {
    New-Item -ItemType Directory -Path $resultsDirectory | Out-Null
}

$arguments = @(
    "test",
    $testProject,
    "--configuration", $Configuration,
    "--filter", "Category=Smoke",
    "--logger", "trx;LogFileName=smoke-tests.trx",
    "--results-directory", $resultsDirectory
)

Push-Location $repoRoot
try {
    & dotnet @arguments
}
finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    throw "Smoke testleri başarısız oldu. Ayrıntılar için sonuç dosyalarına bakın."
}

Write-Host "[Smoke] Smoke testleri başarıyla tamamlandı."