#!/usr/bin/env bash
# Runs CarKitTests on an iOS 26 iPhone simulator, then builds the app for the simulator (unsigned).
set -euo pipefail

# App icon must be opaque (spec §3 App icon): fail the build if the default icon has an alpha channel.
node remotion/scripts/check-icon-alpha.mjs Peugeot408/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
def version(key):
    m = re.search(r"iOS-(\d+)-(\d+)", key)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
candidates = [(version(k), d["udid"]) for k, ds in devices.items() if "iOS-26" in k
              for d in ds if d["name"].startswith("iPhone")]
candidates.sort()
print(candidates[-1][1] if candidates else "")
')

if [ -z "$UDID" ]; then
  echo "::error::No iOS 26 iPhone simulator is available on this runner."
  xcrun simctl list runtimes
  exit 1
fi
echo "Using simulator $UDID"

mkdir -p build
xcodebuild test \
  -project Peugeot408.xcodeproj \
  -scheme CarKit \
  -destination "id=$UDID" \
  -resultBundlePath build/CarKitTests.xcresult \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project Peugeot408.xcodeproj \
  -scheme Peugeot408 \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
