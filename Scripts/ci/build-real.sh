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
zip -r $ZIP_PKG_NAME $SCHEME-Runner.app
popd
mv $WD/$ZIP_PKG_NAME ./
