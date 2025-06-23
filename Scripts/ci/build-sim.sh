#!/bin/bash

set -x

# To run build script for CI

xcodebuild clean build-for-testing \
  -project WebDriverAgent.xcodeproj \
  -derivedDataPath $DERIVED_DATA_PATH \
  -scheme $SCHEME \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO ARCHS=$ARCHS

pushd $WD

zip -r $ZIP_PKG_NAME $SCHEME-Runner.app \
    -x "$SCHEME-Runner.app/Frameworks/Testing.framework" \
       "$SCHEME-Runner.app/Frameworks/libXCTestSwiftSupport.dylib"
popd
mv $WD/$ZIP_PKG_NAME ./
