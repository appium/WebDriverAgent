#!/bin/bash

set -e

clang_version=$(clang --version | python3 -c "import sys, re; print(re.findall(r'clang-([0-9.]+)', sys.stdin.read())[0])")
CLANG_XCODE12_BETA3="1200.0.26.2"
CLANG_XCODE13="1300.0.0.0"
need_workaround=$(python3 -c "vtuple = lambda ver: tuple(map(int, ver.split('.'))); print(int(vtuple('$CLANG_XCODE12_BETA3') <= vtuple('$clang_version') < vtuple('$CLANG_XCODE13')))")

if [[ $need_workaround -ne 1 ]]; then
  carthage "$@"
  exit 0
fi

echo "Applying Carthage build workaround to exclude Apple Silicon binaries. See https://github.com/Carthage/Carthage/issues/3019 for more details"

xcconfig=$(mktemp /tmp/static.xcconfig.XXXXXX)
trap 'rm -f "$xcconfig"' INT TERM HUP EXIT

# For Xcode 12 (beta 3+) make sure EXCLUDED_ARCHS is set to arm architectures otherwise
# the build will fail on lipo due to duplicate architectures.
echo 'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200 = arm64 arm64e armv7 armv7s armv6 armv8' >> $xcconfig
echo 'EXCLUDED_ARCHS = $(inherited) $(EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_$(EFFECTIVE_PLATFORM_SUFFIX)__NATIVE_ARCH_64_BIT_$(NATIVE_ARCH_64_BIT)__XCODE_$(XCODE_VERSION_MAJOR))' >> $xcconfig

XCODE_XCCONFIG_FILE="$xcconfig" carthage "$@"
