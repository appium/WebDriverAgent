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
rm -rf $SCHEME-Runner.app/Frameworks/XCTAutomationSupport.framework
rm -rf $SCHEME-Runner.app/Frameworks/XCTest.framework
rm -rf $SCHEME-Runner.app/Frameworks/XCTestCore.framework
rm -rf $SCHEME-Runner.app/Frameworks/XCTestSupport.framework
rm -rf $SCHEME-Runner.app/Frameworks/XCUIAutomation.framework
rm -rf $SCHEME-Runner.app/Frameworks/XCUnit.framework

zip -r $ZIP_PKG_NAME $SCHEME-Runner.app
popd
mv $WD/$ZIP_PKG_NAME ./
