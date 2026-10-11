# Castelle - Yeni kullanici kayit hatasi (permission-denied) duzeltmesi
# 1) Firebase'de YAYINDA olan kurallari indirir (23.09 kurallari)
# 2) Yedegini alir, users blogunun icine 2 ek izin satiri ekler
# 3) Farki gosterir, onay isterse yayinlar
# Calistirma:  cd "D:\Mobil Projeler\Castelle";  powershell -ExecutionPolicy Bypass -File .\fix_firestore_rules.ps1

$ErrorActionPreference = 'Stop'
$ProjectId = 'castelle-ce64b'
$Root = 'D:\Mobil Projeler\Castelle'
Set-Location $Root
$utf8 = New-Object System.Text.UTF8Encoding($false)

# --- 1) firebase CLI oturumundan erisim token'i al ---
$cfgPath = Join-Path $env:USERPROFILE '.config\configstore\firebase-tools.json'
if (-not (Test-Path $cfgPath)) { throw "Firebase CLI oturumu yok. Once 'firebase login' calistir." }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$refresh = $cfg.tokens.refresh_token
if (-not $refresh) { throw "Refresh token bulunamadi. 'firebase login --reauth' calistir." }

$tok = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
  grant_type    = 'refresh_token'
  refresh_token = $refresh
  client_id     = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com'
  client_secret = 'j9iVZfS8kkCEFUPaAeJV0sAi'
}
$h = @{ Authorization = "Bearer $($tok.access_token)" }

# --- 2) Yayindaki kurallari indir ---
$release = Invoke-RestMethod -Headers $h -Uri "https://firebaserules.googleapis.com/v1/projects/$ProjectId/releases/cloud.firestore"
$ruleset = Invoke-RestMethod -Headers $h -Uri "https://firebaserules.googleapis.com/v1/$($release.rulesetName)"
$live = $ruleset.source.files[0].content
Write-Host "Yayindaki kurallar indirildi ($($release.rulesetName), guncelleme: $($release.updateTime))" -ForegroundColor Cyan

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
[IO.File]::WriteAllText((Join-Path $Root "firestore.rules.live-backup-$stamp"), $live, $utf8)
Write-Host "Yedek: firestore.rules.live-backup-$stamp"

if ($live -match 'Yeni kayit ek izni') { Write-Host 'Ek zaten yapilmis, cikiliyor.' -ForegroundColor Yellow; exit }

# --- 3) users blogunu bul ve ek izinleri ekle ---
$rx = [regex]'match\s+/users/\{(\w+)\}\s*\{'
$m = $rx.Match($live)
if (-not $m.Success) { throw "Kurallarda 'match /users/{...} {' bulunamadi. Yedek dosyayi Claude'a gonder." }
$v = $m.Groups[1].Value

$snippet = @"

      // --- Yeni kayit ek izni (Google / e-posta ile ilk kayit) ---
      // Kendi belgesini olusturabilir; admin/moderator olarak olusturamaz.
      allow create: if request.auth != null
        && request.auth.uid == $v
        && !(request.resource.data.get('role', 'actor') in ['admin', 'moderator']);
      // Google girisinde eski kaydi e-postayla arama: sadece kendi dogrulanmis e-postasi.
      allow list: if request.auth != null
        && request.auth.token.email_verified == true
        && resource.data.email == request.auth.token.email;
      // --- ek izin sonu ---
"@

$new = $live.Insert($m.Index + $m.Length, $snippet)
[IO.File]::WriteAllText((Join-Path $Root 'firestore.rules'), $new, $utf8)

Write-Host "`nEklenen kisim (users blogunun basina):" -ForegroundColor Green
Write-Host $snippet

# --- 4) Yayinla ---
$ans = Read-Host "`nfirestore.rules guncellendi. Simdi yayinlansin mi? (e/h)"
if ($ans -eq 'e') {
  firebase deploy --only firestore:rules --project $ProjectId
  Write-Host "`nTamam. ~1 dk sonra yeni bir Gmail hesabiyla Google girisini dene." -ForegroundColor Green
} else {
  Write-Host "Yayinlanmadi. Hazir oldugunda: firebase deploy --only firestore:rules --project $ProjectId"
}
