#!/usr/bin/env bash
# App Store screenshots (spec §10): runs the StoreScreenshots UI test on a 6.9-inch iPhone simulator
# (1320×2868) with a clean status bar, writing the raw PNGs to build/store-raw.
set -euo pipefail

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
def version(key):
    m = re.search(r"iOS-(\d+)-(\d+)", key)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
candidates = [(version(k), d["name"], d["udid"]) for k, ds in devices.items()
              if "iOS-26" in k for d in ds if d["name"].startswith("iPhone") and "Pro Max" in d["name"]]
candidates.sort()
print(candidates[-1][2] if candidates else "")
')
if [ -z "$UDID" ]; then
  echo "::error::No iOS 26 iPhone Pro Max simulator (6.9-inch) on this runner."
  xcrun simctl list devices available
  exit 1
fi
echo "Using simulator $UDID"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl ui "$UDID" appearance dark

mkdir -p build/store-raw
TEST_RUNNER_SCREENSHOT_DIR="$PWD/build/store-raw" xcodebuild test \
  -project Peugeot408.xcodeproj \
  -scheme StoreScreenshots \
  -destination "id=$UDID" \
  -resultBundlePath build/StoreScreenshots.xcresult \
  FLAVOUR_CONDITION=STORE_BUILD \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" CODE_SIGN_IDENTITY="-" PROVISIONING_PROFILE_SPECIFIER=""

ls -la build/store-raw
