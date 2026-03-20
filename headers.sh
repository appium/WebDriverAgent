#!/usr/bin/env bash
# sync-public-headers.sh
#
# 1. Scans all .h/.m/.mm files under WebDriverAgentLib/ for
#    #import <WebDriverAgentLib/...> statements.
# 2. Resolves each header's actual location (either in WebDriverAgentLib/*
#    or PrivateHeaders/*).
# 3. Creates/updates a symlink inside WebDriverAgentLib/include/
#    so the header is exported by SwiftPM.
#
#   ./sync-public-headers.sh
#
# Run this from the repository root.  Re-run whenever you add or move headers.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WDA_DIR="$ROOT_DIR/WebDriverAgentLib"
INCLUDE_DIR="$WDA_DIR/include"

mkdir -p "$INCLUDE_DIR"

echo "Generating symlinks in ${INCLUDE_DIR#$ROOT_DIR/}"
echo

# 1. collect unique imports (portable, no mapfile)
IMPORTS=$(find "$WDA_DIR" -type f \( -name '*.h' -o -name '*.m' -o -name '*.mm' \) -print0 |
  xargs -0 grep -h -o '#import <WebDriverAgentLib/[^>]*>' |
  sed 's/^#import[[:space:]]*//' |
  sort -u)

# 2. process each import
while IFS= read -r import; do
  header=${import#<WebDriverAgentLib/}; header=${header%>}

  # where is the real file?
  real_path=$(find \
      "$WDA_DIR" \
      "$ROOT_DIR/PrivateHeaders" \
      -type f -name "$header" | head -n 1 || true)

  if [[ -z $real_path ]]; then
    echo "⚠️  $header  … NOT FOUND"
    continue
  fi

  link="$INCLUDE_DIR/WebDriverAgentLib/$header"
  mkdir -p "$(dirname "$link")"

  # portable relative path for the symlink
  rel_dest=$(python3 -c "import os,sys,os.path; print(os.path.relpath(sys.argv[2], sys.argv[1]))" "$(dirname "$link")" "$real_path")
  printf 'Creating symlink %s → %s\n' "${link#$ROOT_DIR/}" "$rel_dest"

  ln -sf "$rel_dest" "$link"
done <<< "$IMPORTS"
