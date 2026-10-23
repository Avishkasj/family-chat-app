#!/usr/bin/env bash
# Captures raw App Store screenshots of FamNest on dedicated simulators,
# using the demo-mode build (sample family, no networking).
#
#   tool/store/capture_store_screenshots.sh
#   python3 tool/store/make_store_screenshots.py
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=store/app-store-screenshots/raw
BUNDLE=app.famnest.chat
RUNTIME=$(xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*' | tail -1)
TMP=$(mktemp -d)

device() { # name type -> udid (created once, reused afterwards)
  local udid
  udid=$(xcrun simctl list devices | grep "$1 (" | grep -oE '[0-9A-F-]{36}' | head -1 || true)
  [ -n "$udid" ] || udid=$(xcrun simctl create "$1" "$2" "$RUNTIME")
  echo "$udid"
}

echo "Building demo app..."
flutter build ios --simulator --debug --flavor prod --dart-define=FAMNEST_DEMO=true >/dev/null
APP=build/ios/iphonesimulator/Runner.app
python3 tool/store/make_demo_photo.py "$TMP/demo_photo.jpg" > "$TMP/photo.json"

# name|route|sheet|tab
SHOTS=(
  "01-family-chat|/chat/family||0"
  "02-family-call|/chat/family|actions|0"
  "03-poll|/chat/grp-weekend-trip||0"
  "04-chats|/||0"
  "05-family|/||1"
  "06-privacy|/||2"
)

# wait_for splash|app <seconds>: polls the screen until the brand-teal splash
# is showing (splash) or gone (app).
wait_for() {
  for _ in $(seq 1 "$2"); do
    sleep 1
    xcrun simctl io "$udid" screenshot "$TMP/probe.png" >/dev/null 2>&1 || continue
    if python3 - "$TMP/probe.png" "$1" <<'PY'; then return 0; fi
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
r, g, b = im.getpixel((im.width // 2, int(im.height * 0.85)))
teal = abs(r - 15) < 14 and abs(g - 123) < 14 and abs(b - 108) < 14
sys.exit(0 if teal == (sys.argv[2] == 'splash') else 1)
PY
  done
}

capture() { # label simulator-name device-type
  local udid data
  udid=$(device "$2" "$3")
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100 --operatorName ""
  # Simulated Face ID so Settings shows "Require Face ID".
  xcrun simctl spawn "$udid" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
  xcrun simctl spawn "$udid" notifyutil -p com.apple.BiometricKit.enrollmentChanged
  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  data="$(xcrun simctl get_app_container "$udid" "$BUNDLE" data)/Library/Application Support/famnest"
  mkdir -p "$data" "$OUT/$1"
  cp "$TMP/demo_photo.jpg" "$data/demo_photo.jpg"
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r name route sheet tab <<<"$shot"
    python3 - "$data/demo.json" "$TMP/photo.json" "$route" "$sheet" "$tab" <<'PY'
import json, sys
out, photo, route, sheet, tab = sys.argv[1:]
cfg = {'route': route, 'tab': int(tab), 'photo': {'file': 'demo_photo.jpg', **json.load(open(photo))}}
if sheet: cfg['sheet'] = sheet
json.dump(cfg, open(out, 'w'))
PY
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE" >/dev/null
    # Wait for this launch's splash (teal) to appear, then to finish.
    wait_for splash 20
    wait_for app 60
    sleep 3  # let sheets / animations finish
    xcrun simctl io "$udid" screenshot "$OUT/$1/$name.png" >/dev/null 2>&1
    echo "  $1/$name.png"
  done
  xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl shutdown "$udid" 2>/dev/null || true
}

capture iphone-6.3 "FamNest Store iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro
capture ipad-13 "FamNest Store iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
rm -rf "$TMP"
echo "Raw screenshots in $OUT"
