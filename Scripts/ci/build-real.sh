#!/bin/bash

# To run build script for CI

xcodebuild clean build-for-testing \
  -project WebDriverAgent.xcodeproj \
  -derivedDataPath $DERIVED_DATA_PATH \
  -scheme $SCHEME \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64

# Only .app is needed.

pushd $WD

# to remove test packages to refer to the device local instead of embedded ones
# XCTAutomationSupport.framework, XCTest.framewor, XCTestCore.framework,
# XCUIAutomation.framework, XCUnit.framework
rm -rf $SCHEME-Runner.app/Frameworks/XC*.framework

# Xcode 16 started generating 5.9MB of 'Testing.framework', but it might not be necessary for WDA
rm -rf $SCHEME-Runner.app/Frameworks/Testing.framework

# This library is used for Swift testing. WDA doesn't include Swift stuff, thus this is not needed.
# Xcode 16 generates a 2.6 MB file size. Xcode 15 was a 1 MB file size.
rm -rf $SCHEME-Runner.app/Frameworks/libXCTestSwiftSupport.dylib



zip -r $ZIP_PKG_NAME $SCHEME-Runner.app
popd
mv $WD/$ZIP_PKG_NAME ./
