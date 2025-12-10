@echo off
REM ============================================================================
REM Pocket LLM Lite - Release Build Script (Windows)
REM ============================================================================
REM This script builds a release APK with:
REM - ProGuard/R8 code shrinking, optimization, and obfuscation (Android)
REM - Dart code obfuscation
REM - Split debug info for crash deobfuscation
REM ============================================================================

echo ==============================================
echo Pocket LLM Lite - Release Build
echo ==============================================

REM Clean previous builds
echo Cleaning previous builds...
call flutter clean

REM Get dependencies
echo Getting dependencies...
call flutter pub get

REM Run analyzer
echo Running analyzer...
call flutter analyze

REM Run tests (if any)
echo Running tests...
call flutter test

REM Create debug symbols directory
set DEBUG_SYMBOLS_DIR=debug_symbols
if not exist "%DEBUG_SYMBOLS_DIR%" mkdir "%DEBUG_SYMBOLS_DIR%"

REM Build release APK with obfuscation
echo Building release APK with obfuscation...
call flutter build apk --release --obfuscate --split-debug-info="%DEBUG_SYMBOLS_DIR%"

REM Check if build succeeded
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
if exist "%APK_PATH%" (
    echo ==============================================
    echo BUILD COMPLETE!
    echo ==============================================
    echo APK Location: %APK_PATH%
    echo Debug Symbols: %DEBUG_SYMBOLS_DIR%
    echo.
    echo Note: Keep debug_symbols folder to deobfuscate crash reports
    echo ==============================================
) else (
    echo ERROR: APK not found at expected location
    exit /b 1
)

pause
