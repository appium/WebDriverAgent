#!/bin/bash
#
# Copyright (c) 2015-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.
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
    "iphone" ) XC_DESTINATION="platform=iOS Simulator,name=`echo $IPHONE_MODEL | tr -d "'"`,OS=$IOS_VERSION";;
    "ipad" ) XC_DESTINATION="platform=iOS Simulator,name=`echo $IPAD_MODEL | tr -d "'"`,OS=$IOS_VERSION";;
    "tv" ) XC_DESTINATION="platform=tvOS Simulator,name=`echo $TV_MODEL | tr -d "'"`,OS=$TV_VERSION";;
    "generic" ) XC_DESTINATION="generic/platform=iOS";;
    "tv_generic" ) XC_DESTINATION="generic/platform=tvOS" XC_MACROS="${XC_MACROS} ARCHS=arm64";; # tvOS only supports arm64
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

  case "${CODE_SIGN:-}" in
    "no" ) XC_MACROS="${XC_MACROS} CODE_SIGNING_ALLOWED=NO";;
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
    output_command=cat
    if [ $(which xcpretty) ] ; then
        output_command=xcpretty
    fi

    XC_BUILD_ARGS=(-project "WebDriverAgent.xcodeproj")
    XC_BUILD_ARGS+=(-scheme "$XC_TARGET")
    XC_BUILD_ARGS+=(-sdk "$XC_SDK")
    XC_BUILD_ARGS+=($XC_ACTION)
    if [[ -n "$XC_DESTINATION" ]]; then
      XC_BUILD_ARGS+=(-destination "${XC_DESTINATION}")
    fi
    if [[ -n "$DERIVED_DATA_PATH" ]]; then
      XC_BUILD_ARGS+=(-derivedDataPath ${DERIVED_DATA_PATH})
    fi
    XC_BUILD_ARGS+=($XC_MACROS $EXTRA_XC_ARGS)

    xcodebuild "${XC_BUILD_ARGS[@]}" | $output_command && exit ${PIPESTATUS[0]}

}

function fastlane_test() {
  # Skip bundle install if already installed (CI already does this)
  if ! bundle check &>/dev/null; then
    bundle install
  fi

  case "${DEST:-}" in
    "iphone" )
      FASTLANE_DEVICE="$(echo $IPHONE_MODEL | tr -d "'") ($IOS_VERSION)"
      ;;
    "ipad" )
      FASTLANE_DEVICE="$(echo $IPAD_MODEL | tr -d "'") ($IOS_VERSION)"
      ;;
    "tv" )
      FASTLANE_DEVICE="$(echo $TV_MODEL | tr -d "'") ($TV_VERSION)"
      ;;
    * )
      echo "Error: Unknown DEST value '${DEST:-}'. DEST must be one of: iphone, ipad, tv"
      exit 1
      ;;
  esac

  echo "Fastlane environment variables:"
  echo "  DEVICE=$FASTLANE_DEVICE"
  echo "  SCHEME=$1"
  echo "  SDK=$XC_SDK"

  SDK="$XC_SDK" DEVICE="$FASTLANE_DEVICE" SCHEME="$1" bundle exec fastlane test
}

define_xc_macros
case "$ACTION" in
  "analyze" ) analyze ;;
  "int_test_1" ) fastlane_test IntegrationTests_1 ;;
  "int_test_2" ) fastlane_test IntegrationTests_2 ;;
  "int_test_3" ) fastlane_test IntegrationTests_3 ;;
  *) xcbuild ;;
esac
