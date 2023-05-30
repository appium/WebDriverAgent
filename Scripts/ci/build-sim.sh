#!/bin/bash

# To run build script for CI

xcodebuild clean build-for-testing \
  -project WebDriverAgent.xcodeproj \
  -derivedDataPath $DERIVED_DATA_PATH \
  -scheme $SCHEME \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO ARCHS=$ARCHS

# simulator needs to build entire build files

pushd $WD
# to remove unnecessary space consuming files
rm -rf Build/Intermediates.noindex
zip -r $ZIP_PKG_NAME Build
popd
mv $WD/$ZIP_PKG_NAME ./
