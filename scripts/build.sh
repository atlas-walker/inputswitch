#!/bin/bash
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
    echo 'La compilación requiere macOS con Command Line Tools.' >&2
    exit 1
fi
mkdir -p build/InputSwitch.app/Contents/MacOS dist
xcrun swiftc -swift-version 6 -O -target arm64-apple-macosx15.0 \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -framework AppKit Sources/InputSwitch/main.swift \
    -o build/InputSwitch.app/Contents/MacOS/InputSwitch
cp Resources/Info.plist build/InputSwitch.app/Contents/Info.plist
plutil -lint build/InputSwitch.app/Contents/Info.plist
codesign --force --sign - --identifier com.andres.inputswitch build/InputSwitch.app
codesign --verify --deep --strict --verbose=2 build/InputSwitch.app
mkdir -p build/release
ditto build/InputSwitch.app build/release/InputSwitch.app
cp docs/PRUEBA-TRABAJO.md build/release/PRUEBA-TRABAJO.md
ditto -c -k --sequesterRsrc build/release dist/InputSwitch-0.1.1-arm64.zip
(cd dist && shasum -a 256 InputSwitch-0.1.1-arm64.zip > InputSwitch-0.1.1-arm64.zip.sha256)
{
    sw_vers
    xcrun swiftc --version
    xcrun --sdk macosx --show-sdk-version
} > dist/build-environment.txt
echo 'Entrega disponible en dist/InputSwitch-0.1.1-arm64.zip'
