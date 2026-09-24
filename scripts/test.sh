#!/bin/bash
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -swift-version 6 -framework IOBluetooth -framework AppKit Sources/HID/*.swift Sources/Transport/*.swift Tests/ProtocolTests.swift -o build/tests/ProtocolTests
build/tests/ProtocolTests
