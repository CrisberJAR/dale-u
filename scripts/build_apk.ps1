# Genera el APK de release con Firebase/Google ya metidos desde .env.
# Uso:  .\scripts\build_apk.ps1
# El .env NO viaja al celular: se embebe al compilar.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path ".env")) {
  throw "Falta .env. Copia .env.example a .env y completa los valores."
}

flutter build apk --release --dart-define-from-file=.env
New-Item -ItemType Directory -Force -Path dist | Out-Null
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "dist\DaleU-1.0.0.apk" -Force
Write-Host "Listo: dist\DaleU-1.0.0.apk"
