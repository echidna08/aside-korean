@echo off
chcp 65001 >nul
title Aside 한글패치
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\patch.ps1" status
echo.
echo 아무 키나 누르면 창이 닫혀요.
pause >nul
