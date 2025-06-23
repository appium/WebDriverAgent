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

       # WDA doesn't use Xcode's testing feature support.
rm -rf $SCHEME-Runner.app/Frameworks/Testing.framework \
       # WDA dpesn't use Swift code.
       $SCHEME-Runner.app/Frameworks/libXCTestSwiftSupport.dylib

zip -r $ZIP_PKG_NAME $SCHEME-Runner.app
popd
mv $WD/$ZIP_PKG_NAME ./
