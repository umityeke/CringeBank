Param(
    [string]$EnvFile,
    [string]$DeviceId = 'windows'
)

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

if ($EnvFile) {
    $resolvedEnvPath = Resolve-Path -Path $EnvFile -ErrorAction Stop
    foreach ($line in Get-Content -Path $resolvedEnvPath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed.StartsWith('export ')) {
            $trimmed = $trimmed.Substring(7)
        }
        $parts = $trimmed.Split('=', 2)
        if ($parts.Count -ne 2) {
            continue
        }
        $name = $parts[0].Trim()
        $value = $parts[1]
        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        Set-Item -Path "Env:$name" -Value $value
    }
}

if (-not $env:CRINGEBANK_REMOTE_EMAIL -or -not $env:CRINGEBANK_REMOTE_PASSWORD) {
    throw "CRINGEBANK_REMOTE_EMAIL ve CRINGEBANK_REMOTE_PASSWORD ortam degiskenleri gerekli."
}

Set-Item -Path Env:CRINGEBANK_RUN_FIREBASE_REMOTE_TESTS -Value 'true'
Remove-Item Env:CRINGEBANK_USE_FIREBASE_EMULATOR -ErrorAction SilentlyContinue
Remove-Item Env:FIREBASE_AUTH_EMULATOR_HOST -ErrorAction SilentlyContinue
Remove-Item Env:FIRESTORE_EMULATOR_HOST -ErrorAction SilentlyContinue
Remove-Item Env:FIREBASE_STORAGE_EMULATOR_HOST -ErrorAction SilentlyContinue

flutter test --device-id $DeviceId integration_test/firebase_emulator_integration_test.dart
