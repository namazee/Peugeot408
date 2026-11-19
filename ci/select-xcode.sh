#!/usr/bin/env bash
# Selects the newest stable Xcode 26.x on the runner, or fails with a clear message.
set -euo pipefail

XCODE=$(ls -d /Applications/Xcode_26*.app 2>/dev/null | grep -vi beta | sort -V | tail -n 1 || true)
if [ -z "$XCODE" ]; then
  echo "::error::Xcode 26 is not installed on this runner image. Use runs-on: macos-26. Found: $(ls -d /Applications/Xcode*.app 2>/dev/null | tr '\n' ' ')"
  exit 1
fi
sudo xcode-select -s "$XCODE/Contents/Developer"
xcodebuild -version
