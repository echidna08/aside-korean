@echo off
chcp 65001 >nul
title Aside 한글패치
net session >nul 2>&1 || (
  echo 관리자 권한이 필요해요. 뜨는 창에서 [예]를 눌러 주세요.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\patch.ps1" uninstall
echo.
echo 아무 키나 누르면 창이 닫혀요.
pause >nul
