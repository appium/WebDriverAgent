#!/bin/bash
#
# Copyright (c) 2015-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.
#

set -ex

function define_xc_macros() {
  XC_MACROS="CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO"

  case "$TARGET" in
    "lib" ) XC_TARGET="WebDriverAgentLib";;
    "runner" ) XC_TARGET="WebDriverAgentRunner";;
    "tv_lib" ) XC_TARGET="WebDriverAgentLib_tvOS";;
    "tv_runner" ) XC_TARGET="WebDriverAgentRunner_tvOS";;
    *) echo "Unknown TARGET"; exit 1 ;;
  esac

  case "${DEST:-}" in
    "iphone" ) XC_DESTINATION="name=$IPHONE_MODEL,OS=$IOS_VERSION";;
    "ipad" ) XC_DESTINATION="name=$IPAD_MODEL,OS=$IOS_VERSION";;
    "tv" ) XC_DESTINATION="name=$TV_MODEL,OS=$TV_VERSION";;
  esac

  case "$ACTION" in
    "build" ) XC_ACTION="build";;
    "analyze" )
      XC_ACTION="analyze"
      XC_MACROS="${XC_MACROS} CLANG_ANALYZER_OUTPUT=plist-html CLANG_ANALYZER_OUTPUT_DIR=\"$(pwd)/clang\""
    ;;
    "unit_test" ) XC_ACTION="test -only-testing:UnitTests";;
    "tv_unit_test" ) XC_ACTION="test -only-testing:UnitTests_tvOS";;
  esac

  case "$SDK" in
    "sim" ) XC_SDK="iphonesimulator";;
    "device" ) XC_SDK="iphoneos";;
    "tv_sim" ) XC_SDK="appletvsimulator";;
    "tv_device" ) XC_SDK="appletvos";;
    *) echo "Unknown SDK"; exit 1 ;;
  esac
}

function analyze() {
  xcbuild
  if [[ -z $(find clang -name "*.html") ]]; then
    echo "Static Analyzer found no issues"
  else
    echo "Static Analyzer found some issues"
    exit 1
  fi
}

function xcbuild() {
    destination=""
    if [[ -n "$XC_DESTINATION" ]]; then
      xcodebuild \
        -project "WebDriverAgent.xcodeproj" \
        -scheme "$XC_TARGET" \
        -sdk "$XC_SDK" \
        -destination "$XC_DESTINATION" \
        $XC_ACTION \
        $XC_MACROS \
      | xcpretty && exit ${PIPESTATUS[0]}
    else
      xcodebuild \
        -project "WebDriverAgent.xcodeproj" \
        -scheme "$XC_TARGET" \
        -sdk "$XC_SDK" \
        $XC_ACTION \
        $XC_MACROS \
      | xcpretty && exit ${PIPESTATUS[0]}
    fi
}

function fastlane_test() {
  if [[ -n "$XC_DESTINATION" ]]; then
    SDK="$XC_SDK" DEST="$XC_DESTINATION" SCHEME="$1" bundle exec fastlane test
  else
    SDK="$XC_SDK" SCHEME="$1" bundle exec fastlane test
  fi
}

./Scripts/bootstrap.sh -d
define_xc_macros
case "$ACTION" in
  "analyze" ) analyze ;;
  "int_test_1" ) fastlane_test IntegrationTests_1 ;;
  "int_test_2" ) fastlane_test IntegrationTests_2 ;;
  "int_test_3" ) fastlane_test IntegrationTests_3 ;;
  *) xcbuild ;;
esac
