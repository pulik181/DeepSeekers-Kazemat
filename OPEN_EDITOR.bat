@echo off
chcp 65001 >nul
title Казематы Дознания — Редактор Godot 4.7.2
set "GODOT_A=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
set "GODOT_B=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_A%" (
    start "" "%GODOT_A%" -e --path "%~dp0"
    exit /b 0
)
if not exist "%GODOT_B%\*" if exist "%GODOT_B%" (
    start "" "%GODOT_B%" -e --path "%~dp0"
    exit /b 0
)
where godot >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    start "" godot -e --path "%~dp0"
    exit /b 0
)
echo Откройте project.godot вручную через ваш Godot 4.7.2!
pause
