# Castelle - Release AAB uretimi
# Kullanim:
#   cd "D:\Mobil Projeler\Castelle"
#   powershell -ExecutionPolicy Bypass -File .\build_release.ps1
# Gorunen surumu degistirmek icin asagidaki $VersionName'i doldur (or. "1.4.0").

$BuildNumber = 25
$VersionName = "2.0.4"
$ProjectDir  = "D:\Mobil Projeler\Castelle"
$SkipAnalyze = $false

$ErrorActionPreference = "Stop"
function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "HATA: $msg" -ForegroundColor Red; exit 1 }

Set-Location -LiteralPath $ProjectDir
if (-not (Test-Path "pubspec.yaml")) { Fail "pubspec.yaml bulunamadi: $ProjectDir" }

# --- 1. Imza dosyasi kontrolu ---
Step "Imza ayarlari kontrol ediliyor"
$keyProps = "android\key.properties"
if (-not (Test-Path $keyProps)) { Fail "android\key.properties yok. Release AAB debug anahtariyla imzalanir ve Play reddeder." }
$storeLine = Select-String -Path $keyProps -Pattern '^\s*storeFile\s*=\s*(.+)$'
if ($storeLine) {
  $storeFile = $storeLine.Matches[0].Groups[1].Value.Trim() -replace '\\\\','\'
  $resolved = if ([IO.Path]::IsPathRooted($storeFile)) { $storeFile } else { Join-Path "android\app" $storeFile }
  if (-not (Test-Path $resolved)) { Fail "Keystore bulunamadi: $resolved" }
  Write-Host "Keystore: $resolved" -ForegroundColor Green
}

# --- 2. pubspec surumu ---
Step "pubspec.yaml surumu guncelleniyor"
$pubPath = (Resolve-Path "pubspec.yaml").Path
$pub = [IO.File]::ReadAllText($pubPath)
$m = [regex]::Match($pub, '(?m)^version:\s*([^\s+]+)(?:\+(\d+))?')
if (-not $m.Success) { Fail "pubspec.yaml icinde 'version:' satiri yok" }
$oldName = $m.Groups[1].Value
$oldCode = $m.Groups[2].Value
if ($oldCode -and [int]$oldCode -ge $BuildNumber) {
  Fail "Mevcut build numarasi ($oldCode) >= $BuildNumber. Play daha buyuk versionCode ister."
}
$newName = if ($VersionName) { $VersionName } else { $oldName }
$pub = $pub.Substring(0, $m.Index) + "version: $newName+$BuildNumber" + $pub.Substring($m.Index + $m.Length)
[IO.File]::WriteAllText($pubPath, $pub, (New-Object Text.UTF8Encoding($false)))
Write-Host "Surum: $oldName+$oldCode  ->  $newName+$BuildNumber" -ForegroundColor Green

# --- 3. Temizlik ve bagimliliklar ---
Step "flutter clean / pub get"
flutter clean;   if ($LASTEXITCODE) { Fail "flutter clean" }
flutter pub get; if ($LASTEXITCODE) { Fail "flutter pub get" }

# --- 4. Analiz ---
if (-not $SkipAnalyze) {
  Step "flutter analyze (hata/uyari varsa durur)"
  flutter analyze --no-fatal-infos
  if ($LASTEXITCODE) { Fail "flutter analyze hata/uyari buldu. Duzeltip tekrar calistir (ya da $SkipAnalyze = $true)." }
}

# --- 5. AAB ---
Step "AAB uretiliyor"
flutter build appbundle --release --build-name=$newName --build-number=$BuildNumber --android-skip-build-dependency-validation
if ($LASTEXITCODE) { Fail "flutter build appbundle" }

$aab = "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $aab)) { Fail "AAB olusmadi: $aab" }

# --- 6. Imza dogrulama (debug anahtari mi?) ---
Step "Imza dogrulaniyor"
$keytool = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\keytool.exe" } else { "keytool" }
try {
  $cert = & $keytool -printcert -jarfile $aab 2>&1 | Out-String
  if ($cert -match "Android Debug") { Fail "AAB DEBUG anahtariyla imzalanmis! build.gradle release signingConfig'i kontrol et." }
  $owner = ($cert -split "`n" | Where-Object { $_ -match "Owner:|Sahibi:" } | Select-Object -First 1)
  $sha   = ($cert -split "`n" | Where-Object { $_ -match "SHA256:" } | Select-Object -First 1)
  Write-Host "Imzalayan: $owner" -ForegroundColor Green
  Write-Host "Upload anahtari $sha" -ForegroundColor Green
} catch {
  Write-Host "keytool bulunamadi, imza kontrolu atlandi (Android Studio JBR icinde bulunur)." -ForegroundColor Yellow
}

# --- 7. Kopyala ---
$outDir = Join-Path $ProjectDir "release"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$target = Join-Path $outDir ("castelle-v{0}-{1}.aab" -f $newName, $BuildNumber)
Copy-Item $aab $target -Force
$sizeMb = [math]::Round((Get-Item $target).Length / 1MB, 1)

Step "TAMAM"
Write-Host "AAB: $target ($sizeMb MB)" -ForegroundColor Green
Write-Host @"

Yuklemeden once:
 - Gercek cihazda: flutter run --release (giris, video, basvuru, revize akisi)
 - Firestore: migrate_private_fields.js --dry-run -> sonra gercek calistirma
 - Kurallar + functions deploy'unu yayinla ayni zamanda yap
 - Play Console > Uygulama butunlugu > Uygulama imzalama anahtari SHA-256/SHA-1 -> Firebase Android uygulamasina ekle
 - App Check 'Enforce' ancak metrikler temizse
"@ -ForegroundColor Yellow
