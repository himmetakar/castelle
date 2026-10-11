@echo off
cd /d "%~dp0"
echo === Castelle AAB build (2.0.3+22) ===
call flutter clean
call flutter pub get
call flutter build appbundle --release --build-name=2.0.3 --build-number=22
echo.
if exist "build\app\outputs\bundle\release\app-release.aab" (
  echo BASARILI: build\app\outputs\bundle\release\app-release.aab
  explorer "build\app\outputs\bundle\release"
) else (
  echo HATA: AAB olusmadi, yukaridaki loglara bakin.
)
pause
