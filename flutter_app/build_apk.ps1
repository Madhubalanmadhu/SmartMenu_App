$ErrorActionPreference = "Stop"

Push-Location -LiteralPath $PSScriptRoot
try {
$localPropertiesPath = Join-Path $PSScriptRoot "android\local.properties"
$flutterCommand = "flutter"
if (Test-Path $localPropertiesPath) {
  Get-Content $localPropertiesPath | ForEach-Object {
    $line = $_.Trim()
    if ($line.StartsWith("flutter.sdk=")) {
      $sdkPath = $line.Split("=", 2)[1].Trim() -replace "\\\\", "\"
      $candidate = Join-Path $sdkPath "bin\flutter.bat"
      if (Test-Path $candidate) {
        $flutterCommand = $candidate
      }
    }
  }
}

$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) {
  Write-Host "Missing .env file. Create one from .env.example first." -ForegroundColor Red
  exit 1
}

$defines = @()
$envValues = @{}
Get-Content $envPath | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq "" -or $line.StartsWith("#")) {
    return
  }

  $parts = $line.Split("=", 2)
  if ($parts.Count -ne 2) {
    return
  }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim().Trim('"').Trim("'")
  $envValues[$key] = $value
  $defines += "--dart-define=$key=$value"
}

$required = @(
  "API_BASE_URL",
  "FIREBASE_API_KEY",
  "FIREBASE_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_PROJECT_ID",
  "FIREBASE_STORAGE_BUCKET"
)

$missing = $required | Where-Object {
  -not $envValues.ContainsKey($_) -or [string]::IsNullOrWhiteSpace($envValues[$_])
}

if ($missing.Count -gt 0) {
  Write-Host "Missing required values in .env:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host "Building SmartMenu Android APK with dart-defines from .env..." -ForegroundColor Green
& $flutterCommand build apk --debug @defines
} finally {
  Pop-Location
}
