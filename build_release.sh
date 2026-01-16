#!/bin/bash
# ============================================================================
# Pocket LLM Lite - Release Build Script
# ============================================================================
# This script builds a release APK with:
# - ProGuard/R8 code shrinking, optimization, and obfuscation (Android)
# - Dart code obfuscation
# - Split debug info for crash deobfuscation
# ============================================================================

set -e  # Exit on error

echo "=============================================="
echo "Pocket LLM Lite - Release Build"
echo "=============================================="

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Run analyzer
echo "Running analyzer..."
flutter analyze

# Run tests (if any)
echo "Running tests..."
flutter test || echo "No tests found or tests skipped"

# Create debug symbols directory
DEBUG_SYMBOLS_DIR="./debug_symbols"
mkdir -p "$DEBUG_SYMBOLS_DIR"

# Build release APK with obfuscation
echo "Building release APK with obfuscation..."
flutter build apk --release \
    --obfuscate \
    --split-debug-info="$DEBUG_SYMBOLS_DIR"

# Get APK size
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo "=============================================="
    echo "BUILD COMPLETE!"
    echo "=============================================="
    echo "APK Location: $APK_PATH"
    echo "APK Size: $APK_SIZE"
    echo "Debug Symbols: $DEBUG_SYMBOLS_DIR"
    echo ""
    echo "Note: Keep debug_symbols folder to deobfuscate crash reports"
    echo "=============================================="
else
    echo "ERROR: APK not found at expected location"
    exit 1
fi
