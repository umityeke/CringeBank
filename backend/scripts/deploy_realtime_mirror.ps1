param(
    [Parameter(HelpMessage = "SQL Server adresi, örn. localhost,1433")]
    [string]$Server = "localhost,1433",

    [Parameter(HelpMessage = "Hedef veritabanı adı")]
    [string]$Database = "CringeBank",

    [Parameter(HelpMessage = "Windows kimliğiyle bağlan (sqlcmd -G)")]
    [switch]$UseIntegratedSecurity = $false,

    [Parameter(HelpMessage = "SQL kimliği kullanıcı adı (UseIntegratedSecurity kapalıyken)")]
    [string]$Username,

    [Parameter(HelpMessage = "SQL kimliği parolası (UseIntegratedSecurity kapalıyken)")]
    [System.Security.SecureString]$PasswordSecure,

    [Parameter(HelpMessage = "sqlcmd yürütülebilir yolu")]
    [string]$SqlCmdPath = "sqlcmd",

    [Parameter(HelpMessage = "Ek sqlcmd argümanları")]
    [string[]]$AdditionalArgs
)

$ErrorActionPreference = 'Stop'

function Write-Step($message) {
    Write-Host "[RealtimeMirror] $message" -ForegroundColor Cyan
}

function ConvertTo-PlainText([System.Security.SecureString]$SecureString) {
    if (-not $SecureString) {
        return $null
    }

    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$bundlePath = Join-Path -Path $scriptRoot -ChildPath 'deploy_realtime_mirror.sqlcmd'

if (-not (Test-Path -Path $bundlePath)) {
    throw "deploy_realtime_mirror.sqlcmd bulunamadı: $bundlePath"
}

if (-not $UseIntegratedSecurity) {
    if (-not $Username) {
        $Username = Read-Host -Prompt 'SQL kullanıcı adı'
    }

    if (-not $PasswordSecure) {
        $PasswordSecure = Read-Host -Prompt 'SQL parolası' -AsSecureString
    }
}

$sqlcmdArgs = @('-S', $Server, '-d', $Database, '-b', '-i', $bundlePath)

if ($UseIntegratedSecurity) {
    $sqlcmdArgs += '-G'
} else {
    $passwordPlain = ConvertTo-PlainText -SecureString $PasswordSecure
    if (-not $passwordPlain) {
        throw 'SQL parolası sağlanamadı.'
    }

    $sqlcmdArgs += @('-U', $Username, '-P', $passwordPlain)
}

if ($AdditionalArgs) {
    $sqlcmdArgs += $AdditionalArgs
}

Write-Step "sqlcmd komutu çalıştırılıyor..."
Write-Host "$SqlCmdPath $($sqlcmdArgs -join ' ')" -ForegroundColor DarkGray

$process = Start-Process -FilePath $SqlCmdPath -ArgumentList $sqlcmdArgs -Wait -PassThru

if ($process.ExitCode -ne 0) {
    throw "sqlcmd çıkış kodu $($process.ExitCode) ile tamamlandı."
}

Write-Step 'Dağıtım başarıyla tamamlandı.'
