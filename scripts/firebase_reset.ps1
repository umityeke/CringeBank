param (
    [Parameter(Mandatory = $true)][string]$NewProjectId,
    [string]$BackupBucket = "",
    [string]$SourceProjectId = "cringe-bank",
    [switch]$ForcePurge,
    [switch]$DryRun,
    [switch]$Execute
)

if ($Execute -and $DryRun) {
    throw "-Execute ve -DryRun birlikte kullanılamaz."
}

$IsDryRun = $DryRun -or (-not $Execute)

Write-Host "==> Firebase reset akışı başlıyor" -ForegroundColor Cyan
Write-Host "Kaynak proje : $SourceProjectId" -ForegroundColor Yellow
Write-Host "Yeni proje   : $NewProjectId" -ForegroundColor Yellow
Write-Host "Çalışma modu : " -NoNewline
if ($IsDryRun) {
    Write-Host "DRY RUN (sadece komut özetleri gösterilecek)" -ForegroundColor Yellow
} else {
    Write-Host "AKTİF (komutlar çalıştırılacak)" -ForegroundColor Red
}

$requiredCommands = @("firebase", "gcloud", "gsutil")
foreach ($cmd in $requiredCommands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Warning "'$cmd' komutu bulunamadı. Lütfen ilgili CLI'ı kurup PATH'e ekleyin."
        if (-not $IsDryRun) {
            throw "Gerekli komut seti eksik olduğu için işlem durduruldu."
        }
    }
}

if (-not $IsDryRun) {
    $confirm = Read-Host "UYARI: $SourceProjectId projesindeki Firestore/Storage/Auth verileri silinecek. Devam etmek için 'DELETE' yazın"
    if ($confirm -cne "DELETE") {
        Write-Host "İşlem kullanıcı tarafından iptal edildi." -ForegroundColor DarkYellow
        return
    }

    New-Item -ItemType Directory -Path "./backups" -Force | Out-Null
}

function Invoke-Step {
    param (
        [string]$Description,
        [string]$Command,
        [ConsoleColor]$Color = [ConsoleColor]::Cyan,
        [switch]$AllowContinueOnError
    )

    Write-Host $Description -ForegroundColor $Color

    if ($Command) {
        if ($IsDryRun) {
            Write-Host "    DRY RUN -> $Command" -ForegroundColor DarkGray
        }
        else {
            try {
                Invoke-Expression $Command
            }
            catch {
                Write-Error $_
                if (-not $AllowContinueOnError) {
                    throw
                }
            }
        }
    }
}

# 1. Opsiyonel yedek
if ($BackupBucket) {
    Invoke-Step "[1/7] GCloud proje seçimi" "gcloud config set project $SourceProjectId | Out-Null"
    Invoke-Step "[1a/7] Firestore yedeği alınıyor -> $BackupBucket" "gcloud firestore export $BackupBucket"
    Invoke-Step "[1b/7] Functions config yedeği" "firebase --project $SourceProjectId functions:config:get | Out-File -FilePath './backups/functions_env.json' -Encoding utf8"
}
else {
    Write-Host "[1/7] Yedek adımı atlandı (BackupBucket verilmedi)" -ForegroundColor DarkGray
}

# 2. İsteğe bağlı purge
if ($ForcePurge) {
    Invoke-Step "[2/7] Mevcut Firestore koleksiyonları siliniyor" "firebase --project $SourceProjectId firestore:delete --all-collections --force" ([ConsoleColor]::Red)
    $bucket = "gs://$SourceProjectId.firebasestorage.app"
    Invoke-Step "[2b/7] Storage bucket boşaltılıyor" "gsutil -m rm -r '$bucket/**'" ([ConsoleColor]::Red)
    Invoke-Step "[2c/7] Authentication kullanıcıları siliniyor" "firebase --project $SourceProjectId auth:delete --force" ([ConsoleColor]::Red) -AllowContinueOnError
}
else {
    Write-Host "[2/7] Force purge atlandı (yeni proje açılacak varsayılıyor)" -ForegroundColor DarkGray
}

# 3. Yeni projeyi CLI'a ekleyin (manuel)
Invoke-Step "[3/7] Firebase CLI'da giriş kontrolü" "firebase login:list" -AllowContinueOnError
Invoke-Step "[3b/7] Yeni Firebase projesini oluştur (manuel)" "firebase projects:create $NewProjectId --display-name 'Cringe Bankasi'" -AllowContinueOnError
Invoke-Step "[3c/7] Projeyi yerel CLI'a ekle" "firebase use --add $NewProjectId" -AllowContinueOnError

# 4. FlutterFire konfigürasyonu
Invoke-Step "[4/7] FlutterFire CLI ile yeni proje yapılandırılacak" "flutterfire configure --project=$NewProjectId --out=lib/firebase_options.dart --platforms=android,ios,macos,web,windows" -AllowContinueOnError

# 5. Deploy hatırlatmaları
Invoke-Step "[5/7] Functions deploy" "firebase deploy --only functions --project $NewProjectId" -AllowContinueOnError
Invoke-Step "[5b/7] Firestore rules deploy" "firebase deploy --only firestore:rules --project $NewProjectId" -AllowContinueOnError
Invoke-Step "[5c/7] Firestore indexes deploy" "firebase deploy --only firestore:indexes --project $NewProjectId" -AllowContinueOnError
Invoke-Step "[5d/7] Storage rules deploy" "firebase deploy --only storage:rules --project $NewProjectId" -AllowContinueOnError

# 6. Seed ve doğrulama
Invoke-Step "[6/7] Seed scriptlerini çalıştır" "node .\\scripts\\seed_store_products.js --project $NewProjectId" -AllowContinueOnError
Invoke-Step "[6b/7] Seed client script" "node .\\scripts\\seed_client.js --project $NewProjectId" -AllowContinueOnError
Invoke-Step "[6c/7] Flutter uygulamasını duman testi" "flutter run -d windows" -AllowContinueOnError

# 7. Son kontrol
Invoke-Step "[7/7] Firestore koleksiyonlarının durumunu doğrula" "firebase --project $NewProjectId firestore:indexes" -AllowContinueOnError

Write-Host "==> Rehber tamamlandı. Manuel adımları uyguladıktan sonra yeni Firebase ortamınız hazır olacaktır." -ForegroundColor Green
