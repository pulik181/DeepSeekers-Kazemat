@echo off
chcp 65001 >nul
title Казематы Дознания — Запуск игры
set "GODOT_A=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
set "GODOT_CON=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
set "GODOT_B=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_A%" (
    if not exist "%~dp0.godot\imported" (
        if exist "%GODOT_CON%" (
            "%GODOT_CON%" --headless --import --path "%~dp0"
        ) else (
            "%GODOT_A%" --headless --import --path "%~dp0"
        )
    )
    start "" "%GODOT_A%" --path "%~dp0"
    exit /b 0
)
if not exist "%GODOT_B%\*" if exist "%GODOT_B%" (
    if not exist "%~dp0.godot\imported" "%GODOT_B%" --headless --import --path "%~dp0"
    start "" "%GODOT_B%" --path "%~dp0"
    exit /b 0
)
where godot >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    if not exist "%~dp0.godot\imported" godot --headless --import --path "%~dp0"
    start "" godot --path "%~dp0"
    exit /b 0
)
echo Откройте папку проекта вручную через Godot 4.7.2 и нажмите F5!
pause
