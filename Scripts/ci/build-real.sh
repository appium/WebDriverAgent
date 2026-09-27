#!/bin/bash

xcodebuild clean build-for-testing \
  -project WebDriverAgent.xcodeproj \
  -derivedDataPath $DERIVED_DATA_PATH \
  -scheme $SCHEME \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64

pushd $WD

# Exclude all libraries in the runner app's top-level Frameworks directory so
# XCTest dependencies resolve from the real device's developer support libraries
# instead of the copies bundled by Xcode. This also covers new dependencies added
# by future Xcode versions. This exclusion is only for real-device builds.
# Keep WebDriverAgentLib.framework inside PlugIns/*.xctest/Frameworks.
zip -r $ZIP_PKG_NAME $SCHEME-Runner.app \
    -x "$SCHEME-Runner.app/Frameworks/*"
popd
mv $WD/$ZIP_PKG_NAME ./
