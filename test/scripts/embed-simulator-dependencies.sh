#!/bin/bash
# Hermetic packaging regression tests. Run on macOS with bash.
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/Scripts/embed-simulator-dependencies.sh"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/bin"
cat > "$FIXTURE/bin/otool" <<'MOCK'
#!/bin/bash
# Fixture binaries contain otool's dependency output.
cat "$2"
MOCK
cat > "$FIXTURE/bin/codesign" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$SIGN_LOG"
[ "${FAIL_SIGN:-0}" = 0 ]
MOCK
chmod +x "$FIXTURE/bin/"*
export PATH="$FIXTURE/bin:$PATH"
export PRODUCT_NAME=WebDriverAgentRunner PLATFORM_NAME=iphonesimulator
export PLATFORM_DIR="$FIXTURE/Xcode With Spaces/iPhoneSimulator.platform"
export BUILT_PRODUCTS_DIR="$FIXTURE/Build Products"
export SIGN_LOG="$FIXTURE/sign.log"
APP="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME-Runner.app"
TEST="$APP/PlugIns/$PRODUCT_NAME.xctest"
PLATFORM_LIB="$PLATFORM_DIR/Developer/Library/Frameworks"
PLATFORM_DYLIB="$PLATFORM_DIR/Developer/usr/lib"
mkdir -p "$PLATFORM_LIB/Testing.framework" "$PLATFORM_LIB/_Testing_Foundation.framework" "$PLATFORM_DYLIB"
printf '\t@rpath/lib_TestingInterop.dylib (compatibility version 1.0.0)\n' > "$PLATFORM_LIB/Testing.framework/Testing"
printf '\t@rpath/Testing.framework/Testing (compatibility version 1.0.0)\n' > "$PLATFORM_LIB/_Testing_Foundation.framework/_Testing_Foundation"
printf '\t@rpath/libswift_Concurrency.dylib (compatibility version 0.0.0, weak)\n' > "$PLATFORM_DYLIB/lib_TestingInterop.dylib"
echo resource > "$PLATFORM_LIB/_Testing_Foundation.framework/resource.txt"

reset_app() {
  rm -rf "$APP"
  mkdir -p "$TEST/Frameworks/Existing.framework"
  printf '\t@rpath/Testing.framework/Testing (compatibility version 1.0.0)\n' > "$APP/$PRODUCT_NAME-Runner"
  printf '\t@rpath/Existing.framework/Existing (compatibility version 1.0.0)\n' > "$TEST/$PRODUCT_NAME"
  printf '\t@rpath/_Testing_Foundation.framework/_Testing_Foundation (compatibility version 1.0.0)\n' > "$TEST/Frameworks/Existing.framework/Existing"
  : > "$SIGN_LOG"
}

# Xcode 27-style missing framework directory; traverse dependencies from
# both the runner and the existing framework inside the test bundle.
reset_app
bash "$SCRIPT"
test -f "$APP/Frameworks/lib_TestingInterop.dylib"
test -f "$APP/Frameworks/_Testing_Foundation.framework/resource.txt"
test ! -e "$APP/Frameworks/Existing.framework"
test ! -s "$SIGN_LOG" # Unsigned builds remain unsigned.
bash "$SCRIPT" # Cycles/repeated dependencies and incremental builds terminate.
test ! -s "$SIGN_LOG"

# Xcode 26-style partially embedded framework; preserve existing content
# while traversing it to find missing transitive dependencies.
reset_app
mkdir -p "$APP/Frameworks/Testing.framework" "$APP/_CodeSignature"
cp "$PLATFORM_LIB/Testing.framework/Testing" "$APP/Frameworks/Testing.framework/Testing"
echo keep > "$APP/Frameworks/Testing.framework/preserved.txt"
bash "$SCRIPT"
test -f "$APP/Frameworks/Testing.framework/preserved.txt"
test -f "$APP/Frameworks/lib_TestingInterop.dylib"
test "$(wc -l < "$SIGN_LOG" | tr -d ' ')" = 3
: > "$SIGN_LOG"
bash "$SCRIPT"
test "$(wc -l < "$SIGN_LOG" | tr -d ' ')" = 1 # Refresh host on incremental builds.

# Failure must not remove pre-existing frameworks or leave added files.
reset_app
mkdir -p "$APP/_CodeSignature"
if FAIL_SIGN=1 bash "$SCRIPT"; then
  echo 'Expected signing failure' >&2
  exit 1
fi
test ! -e "$APP/Frameworks/Testing.framework"
test ! -e "$APP/Frameworks/lib_TestingInterop.dylib"
test -f "$TEST/Frameworks/Existing.framework/Existing"

# Never overwrite/delete an incomplete bundle already present in the app.
reset_app
mkdir -p "$APP/Frameworks/Testing.framework"
echo keep > "$APP/Frameworks/Testing.framework/preserved.txt"
if bash "$SCRIPT"; then
  echo 'Expected incomplete bundle failure' >&2
  exit 1
fi
test -f "$APP/Frameworks/Testing.framework/preserved.txt"

# Physical device builds must not be modified, even with no build settings.
env -u BUILT_PRODUCTS_DIR -u PRODUCT_NAME PLATFORM_NAME=iphoneos bash "$SCRIPT"
echo 'Simulator dependency packaging tests passed'
