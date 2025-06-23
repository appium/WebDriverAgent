#!/bin/bash

set -x

# To run build script for CI

xcodebuild clean build-for-testing \
  -project WebDriverAgent.xcodeproj \
  -derivedDataPath wda_build \
  -scheme $SCHEME \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO ARCHS=$ARCHS

# simulator needs to build entire build files

pushd wda_build
# to remove unnecessary space consuming files
rm -rf Build/Intermediates.noindex

# Xcode 16 started generating 5.9MB of 'Testing.framework', but it might not be necessary for WDA
rm -rf Build/**/Frameworks/Testing.framework

# This library is used for Swift testing. WDA doesn't include Swift stuff, thus this is not needed.
# Xcode 16 generates a 2.6 MB file size. Xcode 15 was a 1 MB file size.
rm -rf Build/**/Frameworks/libXCTestSwiftSupport.dylib

zip -r $ZIP_PKG_NAME Build
popd
mv wda_build/$ZIP_PKG_NAME ./
