# To run build script for CI

xcodebuild clean build-for-testing \
  -project WebDriverAgent.xcodeproj \
  -derivedDataPath $PKG_PATH_IOS_SIM_X86_64 \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO ARCHS="$ARCHS"
