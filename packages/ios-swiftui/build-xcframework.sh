#!/bin/bash
set -euo pipefail

SCHEME="FarmerChatSwiftUI"
OUTPUT_DIR="build"

echo "Building XCFramework for $SCHEME..."

# Build for iOS device
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$OUTPUT_DIR/ios-device" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Build for iOS simulator
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$OUTPUT_DIR/ios-simulator" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create XCFramework
xcodebuild -create-xcframework \
    -framework "$OUTPUT_DIR/ios-device.xcarchive/Products/Library/Frameworks/$SCHEME.framework" \
    -framework "$OUTPUT_DIR/ios-simulator.xcarchive/Products/Library/Frameworks/$SCHEME.framework" \
    -output "$OUTPUT_DIR/$SCHEME.xcframework"

echo "XCFramework created at $OUTPUT_DIR/$SCHEME.xcframework"
