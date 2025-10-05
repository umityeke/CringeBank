param(
    [switch]$Deep,
    [switch]$DryRun,
    [switch]$SkipFlutterClean
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host $msg -ForegroundColor DarkGray }
function Write-Ok($msg)   { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }

try {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
} catch {
    $repoRoot = (Get-Location).Path
}

Write-Info "CRINGE CLEAN - Repo: $repoRoot"

# Optionally run `flutter clean` first
if (-not $SkipFlutterClean) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) {
        if ($DryRun) {
            Write-Warn "[DRY-RUN] Would run: flutter clean"
        } else {
            Write-Info "Running: flutter clean"
            flutter clean | Out-Host
        }
    } else {
    Write-Skip "flutter not found in PATH - skipping flutter clean"
    }
}

function Remove-Target([string]$relativePath) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        if ($DryRun) {
            Write-Warn "[DRY-RUN] Would remove: $relativePath"
        } else {
            try {
                Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Ok "Removed: $relativePath"
            } catch {
                Write-Warn "Failed to remove: $relativePath - $($_.Exception.Message)"
            }
        }
    } else {
        Write-Skip "Not found: $relativePath"
    }
}

# Core safe targets
$targets = @(
    'build',
    '.dart_tool',
    'windows\flutter\ephemeral',
    'windows\build',
    'android\build',
    'android\.gradle',
    'linux\build',
    'macos\build',
    'ios\build'
)

# Deeper platform outputs (optional)
if ($Deep) {
    $targets += @(
        'windows\x64',
        'windows\x86',
        'build\windows',
        'build\android',
        'build\ios',
        'build\linux',
        'build\macos',
        'build\web',
        'ios\Pods',
        'macos\Pods'
    )
}

Write-Info "Cleaning targets (Deep=$Deep, DryRun=$DryRun, SkipFlutterClean=$SkipFlutterClean)..."
foreach ($t in $targets) { Remove-Target $t }

Write-Ok "Cleanup finished."
