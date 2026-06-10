#!/bin/bash
# Embed the WebDriverAgentBroadcast ReplayKit upload extension into the
# wrapping XCTRunner host app.
#
# Apple's USES_XCTRUNNER auto-generates a Runner.app around UI-testing
# .xctest bundles after all target build phases have run, so an appex
# cannot reach Runner.app/PlugIns through a regular embed build phase.
# The extension target is built into BUILT_PRODUCTS_DIR via a target
# dependency of WebDriverAgentRunner; this scheme post-action copies it
# into Runner.app/PlugIns, fixes its bundle id to match the host app
# (extensions must be prefixed by the host's CFBundleIdentifier, which
# Xcode suffixes with '.xctrunner') and re-signs inner-first.
#
# Limitations:
#   - Touches XCTRunner internals; may need updates across Xcode versions.
#   - iOS only; the extension is not built for tvOS.
#   - Cloud device farms that re-sign WDA must re-sign the nested appex
#     with the same team first (or use codesign --deep); see
#     docs/broadcast-extension.md.

set -euo pipefail

RUNNER_APP="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}-Runner.app"
APPEX_NAME="WebDriverAgentBroadcast.appex"
APPEX_SRC="${BUILT_PRODUCTS_DIR}/${APPEX_NAME}"

if [ ! -d "$RUNNER_APP" ]; then
    echo "warning: ${PRODUCT_NAME}-Runner.app not found at $RUNNER_APP; skipping broadcast extension embed"
    exit 0
fi

if [ ! -d "$APPEX_SRC" ]; then
    echo "warning: $APPEX_NAME not found at $APPEX_SRC; skipping broadcast extension embed"
    exit 0
fi

APPEX_DST="$RUNNER_APP/PlugIns/$APPEX_NAME"
rm -rf "$APPEX_DST"
mkdir -p "$RUNNER_APP/PlugIns"
cp -R "$APPEX_SRC" "$APPEX_DST"

# Extensions must carry a bundle id prefixed by the host app's. The host id is only final at
# this point (Xcode appends '.xctrunner'; downstream tooling may override the prefix), so
# always derive the appex id from the embedded Runner.app instead of trusting build settings.
HOST_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$RUNNER_APP/Info.plist")
WANT_ID="${HOST_ID}.broadcast"
CURRENT_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APPEX_DST/Info.plist")
if [ "$CURRENT_ID" != "$WANT_ID" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $WANT_ID" "$APPEX_DST/Info.plist"
fi

# Re-codesign since we modified the bundle after Xcode signed it: the appex first (its bundle
# id may just have changed, so do NOT preserve the identifier), then the app so its seal covers
# the new nested code. In a scheme post-action context Xcode's CODE_SIGN_* env vars are not
# exposed, so discover the existing signing identity from the already-signed bundle.
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
                 --preserve-metadata=entitlements "$APPEX_DST"
        codesign --force --sign "$EXISTING_IDENT" \
                 --preserve-metadata=identifier,entitlements "$RUNNER_APP"
    else
        echo "warning: bundle is signed but no identity discovered; signature will be invalid"
    fi
fi

echo "embedded $APPEX_NAME into $RUNNER_APP (bundle id $WANT_ID)"
