# Genera el APK (para instalar a mano) y el AAB (para Play Store) de release,
# con Firebase/Google ya metidos desde .env.
#
# Uso:  .\scripts\build_apk.ps1
# Sube el número de versión en pubspec.yaml (version: 1.0.1+2) antes de
# cada entrega: Play Store rechaza un AAB con el mismo número (+2).
#
# El .env NO viaja al celular: se embebe al compilar.
# --obfuscate + --split-debug-info: el código queda ofuscado y los
# símbolos se guardan aparte para leer los errores de Crashlytics.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path ".env")) {
  throw "Falta .env. Copia .env.example a .env y completa los valores."
}
if (-not (Test-Path "android\key.properties")) {
  Write-Warning "Sin android\key.properties el release se firma con la llave de debug (no sirve para Play Store)."
}

$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if ($null -eq $versionLine) { throw "No encontré 'version:' en pubspec.yaml" }
$version = $versionLine.Matches[0].Groups[1].Value
$name = ($version -split '\+')[0]

$symbols = "build\symbols\$version"
New-Item -ItemType Directory -Force -Path $symbols | Out-Null

flutter build apk --release --dart-define-from-file=.env --obfuscate --split-debug-info=$symbols
flutter build appbundle --release --dart-define-from-file=.env --obfuscate --split-debug-info=$symbols

New-Item -ItemType Directory -Force -Path dist | Out-Null
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "dist\DaleU-$name.apk" -Force
Copy-Item "build\app\outputs\bundle\release\app-release.aab" "dist\DaleU-$name.aab" -Force
Write-Host "Listo:"
Write-Host "  dist\DaleU-$name.apk  (instalar a mano)"
Write-Host "  dist\DaleU-$name.aab  (subir a Play Console)"
Write-Host "  $symbols  (guárdalo: sirve para leer los errores ofuscados)"
