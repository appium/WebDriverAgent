#!/bin/bash
# Embed the WDA app icon into the wrapping XCTRunner host app so the
# installed WebDriverAgent shows the Appium logo on the iOS home screen
# instead of a blank icon.
#
# Apple's USES_XCTRUNNER auto-generates a Runner.app around UI-testing
# .xctest bundles but does not inherit icons from the test bundle's
# asset catalog. actool produces AppIcon*.png + Assets.car inside
# PlugIns/<product>.xctest/ where iOS never looks. This script lifts
# them up to the Runner.app root and patches Info.plist accordingly.
#
# Limitations:
#   - Touches XCTRunner internals; may need updates across Xcode versions.
#   - iOS only; tvOS uses different "Brand Assets" and is not handled.
#   - Cloud device farms that re-sign WDA must preserve these changes.

set -euo pipefail

RUNNER_APP="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}-Runner.app"
XCTEST="${RUNNER_APP}/PlugIns/${PRODUCT_NAME}.xctest"

if [ ! -d "$RUNNER_APP" ]; then
    echo "warning: ${PRODUCT_NAME}-Runner.app not found at $RUNNER_APP; skipping icon embed"
    exit 0
fi

if [ ! -d "$XCTEST" ]; then
    echo "warning: ${PRODUCT_NAME}.xctest not found inside Runner.app; skipping icon embed"
    exit 0
fi

shopt -s nullglob
ICONS=("$XCTEST"/AppIcon*.png)
if [ ${#ICONS[@]} -eq 0 ]; then
    echo "warning: no compiled AppIcon*.png found inside $XCTEST; skipping icon embed"
    exit 0
fi

PLIST="$RUNNER_APP/Info.plist"

# Everything below mutates a bundle Xcode already signed, so keep enough state
# to undo it: a failed re-sign must not leave an uninstallable runner behind.
PLIST_BACKUP=$(mktemp)
CERT_DIR=$(mktemp -d)
trap 'rm -rf "$PLIST_BACKUP" "$CERT_DIR"' EXIT
cp "$PLIST" "$PLIST_BACKUP"
ADDED_FILES=()

restore_bundle() {
    cp -f "$PLIST_BACKUP" "$PLIST"
    if [ ${#ADDED_FILES[@]} -gt 0 ]; then
        rm -f "${ADDED_FILES[@]}"
    fi
}

for icon in "${ICONS[@]}"; do
    dest="$RUNNER_APP/$(basename "$icon")"
    [ -e "$dest" ] || ADDED_FILES+=("$dest")
    cp -f "$icon" "$dest"
done
if [ -f "$XCTEST/Assets.car" ]; then
    [ -e "$RUNNER_APP/Assets.car" ] || ADDED_FILES+=("$RUNNER_APP/Assets.car")
    cp -f "$XCTEST/Assets.car" "$RUNNER_APP/"
fi
/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons~ipad" "$PLIST" 2>/dev/null || true

/usr/libexec/PlistBuddy -c "Add :CFBundleIcons dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName string AppIcon" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0 string AppIcon60x60" "$PLIST"

/usr/libexec/PlistBuddy -c "Add :CFBundleIcons~ipad dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconName string AppIcon" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:0 string AppIcon60x60" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconFiles:1 string AppIcon76x76" "$PLIST"

# Re-codesign since we modified the bundle after Xcode signed it. Scheme
# post-actions never receive EXPANDED_CODE_SIGN_IDENTITY, so the signer has to
# be recovered from the already-signed bundle.
if [ -d "$RUNNER_APP/_CodeSignature" ]; then
    # Capture the signature info once. Piping codesign straight into
    # `awk ... exit` makes awk close the pipe early, killing codesign with
    # SIGPIPE -- which `set -o pipefail` turns into a fatal error. That trips
    # only when an Authority line exists, i.e. on every real-device build.
    SIGN_INFO=$(codesign -dvv "$RUNNER_APP" 2>&1 || true)

    if grep -q '^Signature=adhoc' <<< "$SIGN_INFO"; then
        # Simulator builds are ad-hoc signed; re-sign them ad-hoc.
        EXISTING_IDENT="-"
    else
        # Identify the signer by leaf-certificate SHA-1, never by Authority
        # display name: duplicate identities can share a name, and codesign
        # then rejects the name as ambiguous (Apple TN3161).
        EXISTING_IDENT=""
        if codesign -d --extract-certificates="$CERT_DIR/leaf" "$RUNNER_APP" 2>/dev/null \
                && [ -f "$CERT_DIR/leaf0" ]; then
            EXISTING_IDENT=$(shasum -a 1 "$CERT_DIR/leaf0" | awk '{print toupper($1)}')
        fi
        if [ -z "$EXISTING_IDENT" ]; then
            EXISTING_IDENT=$(awk -F'=' '/^Authority/ {print $2; exit}' <<< "$SIGN_INFO")
        fi
    fi

    if [ -z "$EXISTING_IDENT" ] || ! codesign --force --sign "$EXISTING_IDENT" \
            --preserve-metadata=identifier,entitlements "$RUNNER_APP"; then
        # A modified-but-stale-signed bundle fails to install, which would break
        # the session over a cosmetic icon. Undo instead.
        restore_bundle
        echo "warning: could not re-sign $RUNNER_APP; skipped icon embed"
        exit 0
    fi
fi

echo "embedded icon into $RUNNER_APP"
