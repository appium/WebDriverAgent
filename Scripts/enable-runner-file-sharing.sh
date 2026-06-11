#!/bin/bash
# Expose the Runner.app Documents folder in the iOS Files app ("On My
# iPhone" location) and over AFC house-arrest document sharing so files
# written into the WDA container can be browsed on-device and pulled off
# with go-ios/ifuse.
#
# Apple's USES_XCTRUNNER auto-generates a Runner.app around UI-testing
# .xctest bundles but does not inherit custom Info.plist keys from the
# test bundle, so UIFileSharingEnabled/LSSupportsOpeningDocumentsInPlace
# declared in WebDriverAgentRunner/Info.plist end up buried inside
# PlugIns/<product>.xctest where iOS never looks. This script lifts them
# up into the Runner.app Info.plist, along with CFBundleDisplayName so
# the Files app folder (and home screen label) gets a friendly name.
#
# Limitations:
#   - Touches XCTRunner internals; may need updates across Xcode versions.
#   - iOS only; tvOS has no Files app.
#   - Cloud device farms that re-sign WDA must preserve these changes.

set -euo pipefail

RUNNER_APP="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}-Runner.app"
XCTEST="${RUNNER_APP}/PlugIns/${PRODUCT_NAME}.xctest"

if [ ! -d "$RUNNER_APP" ]; then
    echo "warning: ${PRODUCT_NAME}-Runner.app not found at $RUNNER_APP; skipping file sharing setup"
    exit 0
fi

if [ ! -d "$XCTEST" ]; then
    echo "warning: ${PRODUCT_NAME}.xctest not found inside Runner.app; skipping file sharing setup"
    exit 0
fi

SRC_PLIST="$XCTEST/Info.plist"
DST_PLIST="$RUNNER_APP/Info.plist"

CHANGED=0
for KEY in UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace; do
    VALUE=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$SRC_PLIST" 2>/dev/null || true)
    if [ -z "$VALUE" ]; then
        echo "warning: $KEY not set in ${PRODUCT_NAME}.xctest Info.plist; skipping"
        continue
    fi
    /usr/libexec/PlistBuddy -c "Delete :$KEY" "$DST_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :$KEY bool $VALUE" "$DST_PLIST"
    CHANGED=1
done

DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$SRC_PLIST" 2>/dev/null || true)
if [ -n "$DISPLAY_NAME" ]; then
    /usr/libexec/PlistBuddy -c "Delete :CFBundleDisplayName" "$DST_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $DISPLAY_NAME" "$DST_PLIST"
    CHANGED=1
fi

if [ "$CHANGED" = "0" ]; then
    echo "warning: no file sharing keys found; Runner.app left untouched"
    exit 0
fi

# Re-codesign since we modified the bundle after Xcode signed it.
# In a scheme post-action context Xcode's CODE_SIGN_* env vars are not exposed,
# so discover the existing signing identity from the already-signed bundle.
if [ -d "$RUNNER_APP/_CodeSignature" ]; then
    # Capture the signature info once. Piping codesign straight into
    # `awk ... exit` makes awk close the pipe early, killing codesign with
    # SIGPIPE -- which `set -o pipefail` turns into a fatal error. That trips
    # only when an Authority line exists, i.e. on every real-device build.
    SIGN_INFO=$(codesign -dvv "$RUNNER_APP" 2>&1 || true)
    EXISTING_IDENT="${EXPANDED_CODE_SIGN_IDENTITY:-}"
    if [ -z "$EXISTING_IDENT" ]; then
        EXISTING_IDENT=$(awk -F'=' '/^Authority/ {print $2; exit}' <<< "$SIGN_INFO")
    fi
    # Simulator builds are ad-hoc signed: there is no Authority line, but the
    # bundle can still be re-signed ad-hoc with an identity of "-".
    if [ -z "$EXISTING_IDENT" ] && grep -q '^Signature=adhoc' <<< "$SIGN_INFO"; then
        EXISTING_IDENT="-"
    fi
    if [ -n "$EXISTING_IDENT" ]; then
        codesign --force --sign "$EXISTING_IDENT" \
                 --preserve-metadata=identifier,entitlements "$RUNNER_APP"
    else
        echo "warning: bundle is signed but no identity discovered; signature will be invalid"
    fi
fi

echo "enabled Files app sharing in $RUNNER_APP"
