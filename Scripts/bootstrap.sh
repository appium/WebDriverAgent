#!/bin/bash
#
# Copyright (c) 2015-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.
#

set -e

export PATH=$PATH:/usr/local/bin
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BOLD="\033[1m"

if [[ ! -f Scripts/bootstrap.sh ]]; then
  echo "Run this script from the root of repository"
  exit 1
fi

function assert_has_carthage() {
  if ! command -v carthage > /dev/null; then
    echo "Please make sure that you have Carthage installed (https://github.com/Carthage/Carthage)"
    echo "Note: We are expecting that carthage installed in /usr/local/bin/"
    exit 1;
  fi
}

function assert_has_npm() {
  if ! command -v npm > /dev/null; then
    echo "Please make sure that you have npm installed (https://www.npmjs.com)"
    echo "Note: We are expecting that npm installed in /usr/local/bin/"
    exit 1
  fi
}

function print_usage() {
  echo "Usage:"
  echo $'\t -d Fetch & build dependencies'
  echo $'\t -D Fetch & build dependencies using SSH for downloading GitHub repositories'
  echo $'\t -h print this help'
}

function join_by {
  local IFS="$1"; shift; echo "$*";
}

function fetch_and_build_dependencies() {
  echo -e "${BOLD}Fetching dependencies"
  assert_has_carthage
  if ! cmp -s Cartfile.resolved Carthage/Cartfile.resolved; then
    runtimes_with_devices=`xcrun simctl list -j devices | python -c "import sys,json;print(' '.join(map(lambda x: x[0], filter(lambda x: len([y for y in x[1] if y.get('availability') == '(available)' or y.get('isAvailable')]) > 0, json.load(sys.stdin)['devices'].items()))))"`
    platforms=(iOS)
    if echo "$runtimes_with_devices" | grep -q tvOS; then
      platforms+=(tvOS)
    else
      echo "tvOS platform will not be included into Carthage bootstrap, because no Simulator devices have been created for it"
    fi
    platform_str=$(join_by , "${platforms[@]}")
    bash "$DIR/carthage-wrapper.sh" bootstrap $USE_SSH --platform "$platform_str" $NO_USE_BINARIES
    cp Cartfile.resolved Carthage
  else
    echo "Dependencies up-to-date"
  fi
}

FETCH_DEPS=1

while getopts " d D h n" option; do
  case "$option" in
    d ) FETCH_DEPS=1;;
    D ) FETCH_DEPS=1; USE_SSH="--use-ssh";;
    n ) NO_USE_BINARIES="--no-use-binaries";;
    h ) print_usage; exit 1;;
    *) exit 1 ;;
  esac
done

if [[ -n ${FETCH_DEPS+x} ]]; then
  fetch_and_build_dependencies
fi
