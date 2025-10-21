Param(
	[string]$DeviceId = 'windows'
)

$ErrorActionPreference = 'Stop'

# Proje kokune git
Set-Location (Join-Path $PSScriptRoot '..')

# Emulasyon icin gerekli ortam degiskenleri
$env:CRINGEBANK_USE_FIREBASE_EMULATOR = 'true'
$env:FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099'
$env:FIRESTORE_EMULATOR_HOST = 'localhost:8787'
Remove-Item Env:CRINGEBANK_RUN_FIREBASE_REMOTE_TESTS -ErrorAction SilentlyContinue
Remove-Item Env:CRINGEBANK_REMOTE_EMAIL -ErrorAction SilentlyContinue
Remove-Item Env:CRINGEBANK_REMOTE_PASSWORD -ErrorAction SilentlyContinue

# Emulatorler ile entegrasyon testlerini calistir
firebase emulators:exec --project demo-cringebank --only="firestore,auth" -- "flutter test --device-id $DeviceId integration_test/firebase_emulator_integration_test.dart"
