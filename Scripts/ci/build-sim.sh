#!/bin/bash

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
zip -r $ZIP_PKG_NAME Build
popd
mv wda_build/$ZIP_PKG_NAME ./
