#!/bin/bash
# Make the iOS simulator runner launchable without xcodebuild's DYLD paths.
# Xcode's generated runner does not always include all XCTest dependencies
# (for example lib_TestingInterop and _Testing_Foundation in Xcode 26).
# Run as a scheme build post-action, after Xcode assembles/signs the runner.
set -euo pipefail

# Device builds need their original signing/provisioning and packaging rules.
[ "${PLATFORM_NAME:-}" = iphonesimulator ] || exit 0

RUNNER_APP="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}-Runner.app"
XCTEST="$RUNNER_APP/PlugIns/${PRODUCT_NAME}.xctest"
[ -d "$RUNNER_APP" ] && [ -d "$XCTEST" ] || exit 0

PLATFORM_DEVELOPER="${PLATFORM_DIR}/Developer"
FRAMEWORKS="$RUNNER_APP/Frameworks"
SEARCH_PATHS=(
  "$FRAMEWORKS"
  "$XCTEST/Frameworks"
)
SOURCE_PATHS=(
  "$PLATFORM_DEVELOPER/Library/Frameworks"
  "$PLATFORM_DEVELOPER/Library/PrivateFrameworks"
  "$PLATFORM_DEVELOPER/usr/lib"
)
QUEUE=("$RUNNER_APP/${PRODUCT_NAME}-Runner" "$XCTEST/$PRODUCT_NAME")
VISITED=()
ADDED=()

# Only add missing bundles; do not replace frameworks already embedded by
# Xcode. Roll back additions if inspection, copying, or signing fails.
cleanup() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    for item in ${ADDED[@]+"${ADDED[@]}"}; do
      rm -rf "$item"
    done
    echo "error: failed to embed simulator XCTest dependencies" >&2
  fi
}
trap cleanup EXIT

for ((index = 0; index < ${#QUEUE[@]}; index++)); do
  binary="${QUEUE[$index]}"
  visited=false
  for item in ${VISITED[@]+"${VISITED[@]}"}; do
    if [ "$item" = "$binary" ]; then
      visited=true
      break
    fi
  done
  if [ "$visited" = true ]; then
    continue
  fi
  VISITED+=("$binary")
  dependencies=$(otool -L "$binary")
  # Universal binaries repeat dependencies per architecture. VISITED avoids
  # cycles and repeated inspection; only @rpath dependencies need embedding.
  while IFS= read -r relative; do
    resolved=""
    for directory in "${SEARCH_PATHS[@]}"; do
      if [ -f "$directory/$relative" ]; then
        resolved="$directory/$relative"
        break
      fi
    done
    if [ -z "$resolved" ]; then
      for directory in "${SOURCE_PATHS[@]}"; do
        if [ ! -f "$directory/$relative" ]; then
          continue
        fi
        # Frameworks must be copied as bundles, including their resources.
        component="${relative%%/*}"
        destination="$FRAMEWORKS/$component"
        if [ -e "$destination" ]; then
          echo "error: existing dependency bundle lacks $relative" >&2
          exit 1
        fi
        mkdir -p "$FRAMEWORKS"
        ADDED+=("$destination")
        ditto "$directory/$component" "$destination"
        resolved="$FRAMEWORKS/$relative"
        echo "Embedded simulator dependency: $component"
        break
      done
    fi
    # Dependencies not provided by this Xcode platform (e.g. Swift runtime
    # libraries) remain the responsibility of the simulator runtime.
    if [ -n "$resolved" ]; then
      QUEUE+=("$resolved")
    fi
  done < <(printf '%s\n' "$dependencies" | sed -n 's/^[[:space:]]*@rpath\/\(.*\) (compatibility version.*$/\1/p')
done

if [ -d "$RUNNER_APP/_CodeSignature" ]; then
  # Simulator runners use ad-hoc signing. Preserve the host's entitlements.
  for item in ${ADDED[@]+"${ADDED[@]}"}; do
    codesign --force --sign - "$item"
  done
  # Xcode can refresh the host template during incremental builds even when
  # all dependencies are already present. Refresh its signature in that case.
  codesign --force --sign - --preserve-metadata=identifier,entitlements "$RUNNER_APP"
fi
