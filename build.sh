#!/usr/bin/env bash
set -euo pipefail

PROJECT="BLESensors.xcodeproj"
SCHEME="BLESensors"
APP_NAME="BLE Thermo.app"
OUT_DIR="$(pwd)/build"
DERIVED="$OUT_DIR/.derived"
DEST="platform=macOS,arch=arm64"

# Pipe through xcpretty if available, otherwise raw output
pretty() { xcpretty 2>/dev/null || cat; }

echo "Resolving Swift packages..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED" \
    -resolvePackageDependencies \
    2>&1 | grep -v "DVTErrorPresenter\|CoreSimulator\|Domain:\|Code:\|Failure\|Recovery\|--$"

echo "Building $SCHEME (Release)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "$DEST" \
    -derivedDataPath "$DERIVED" \
    -disableAutomaticPackageResolution \
    BUILD_DIR="$OUT_DIR" \
    CONFIGURATION_BUILD_DIR="$OUT_DIR" \
    | pretty

echo ""
echo "Done: $OUT_DIR/$APP_NAME"
