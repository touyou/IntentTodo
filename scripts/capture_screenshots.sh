#!/bin/bash
#
# Captures the App Store submission screenshots for every platform and locale.
#
#   ./scripts/capture_screenshots.sh                 # everything
#   ./scripts/capture_screenshots.sh iphone ipad     # only these platforms
#   LOCALES="ja" ./scripts/capture_screenshots.sh    # only this locale
#   ./scripts/capture_screenshots.sh duo-closed      # iPhone Duo, folded
#   ./scripts/capture_screenshots.sh duo-open        # iPhone Duo, unfolded (open it in DeviceHub first)
#
# Output goes to Screenshots/<platform>/<locale>/NN-name.png (gitignored).
#
# Two mechanisms, because the platforms need different things:
#
#   * iPhone / iPad / Apple Watch — XCUITest drives the app and attaches
#     `XCUIScreen.main.screenshot()`, which is the device's framebuffer at exactly the pixel
#     size App Store Connect asks for.
#   * Apple Vision Pro — `simctl io screenshot`, which renders the whole simulated room at
#     3840x2160 (the size ASC wants). `XCUIScreen.main` returns a 1x1 image there, and
#     `app.screenshot()` returns a flat, clipped rectangle of the window with no environment
#     around it. Navigation therefore goes through deep links rather than taps.
#
# iPhone Duo is shot both folded (outer screen, portrait 1398x2034) and unfolded (inner
# screen, landscape 2853x2007). The fold can't be changed from the command line, only with
# the button under the device in DeviceHub, so the two Duo platforms only run when named
# and each checks the current state first, stopping if it doesn't match. Unfolded, the test
# captures the inner screen (`SCREENSHOT_DUO_OPEN`); its framebuffer stays portrait-shaped,
# so this script turns it 90° clockwise and sizes it to 2853x2007.
#
# Never pass CODE_SIGNING_ALLOWED=NO to `xcodebuild test`: it skips re-signing the UI test
# runner and AppIntentsTesting-adjacent services reject it with
# AppIntentsServicesSecurityErrorDomain 803. See docs/devlog/2026-09-10-xcode27-rc-recheck.md.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/Screenshots"
WORK="${SCREENSHOT_WORK_DIR:-$ROOT/.screenshot-runs}"
LOCALES="${LOCALES:-en ja}"

BUNDLE_ID="dev.touyou.IntentTodo"

# platform | scheme | test target/class | destination
#
# iPhone Duo only exists on the iOS 27.1 runtime.
DUO_DEST="${DUO_DEST:-platform=iOS Simulator,name=iPhone Duo,OS=27.1}"
DUO_OPEN_SIZE="2853x2007"
# The folded Duo's inner screen (all black) captures smaller than this.
DUO_INNER_BLANK_MAX_BYTES=1000000

UITEST_PLATFORMS=(
  "iphone|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0"
  "ipad|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0"
  "duo-closed|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|$DUO_DEST"
  "duo-open|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|$DUO_DEST"
  "mac|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|platform=macOS,arch=arm64"
  "watch|IntentTodoWatchAppUITest|IntentTodoWatchAppUITest/WatchScreenshotTests|platform=watchOS Simulator,name=Apple Watch Ultra 4 (49mm),OS=27.0"
)

requested=("$@")
failed=()

wanted() {
  # With no arguments, everything except the Duo: its two platforms need the device folded
  # one way and then the other, which a single run can't do.
  if [ ${#requested[@]} -eq 0 ]; then
    case "$1" in duo-*) return 1 ;; esac
    return 0
  fi
  for name in "${requested[@]}"; do
    [ "$name" = "$1" ] && return 0
  done
  return 1
}

region_for() {
  case "$1" in
    ja) echo JP ;;
    *)  echo US ;;
  esac
}

mkdir -p "$WORK"

# --- XCUITest-driven platforms ------------------------------------------------------------

# The destination's UDID: id= as is, name=/OS= looked up in that runtime.
udid_for() {
  local destination=$1 udid name os
  udid=$(echo "$destination" | sed -nE 's/.*id=([0-9A-Fa-f-]{36}).*/\1/p')
  if [ -z "$udid" ]; then
    name=$(echo "$destination" | sed -nE 's/.*name=([^,]+).*/\1/p')
    os=$(echo "$destination" | sed -nE 's/.*OS=([0-9.]+).*/\1/p')
    udid=$(xcrun simctl list devices available \
      | awk -v os="-- iOS $os --" -v name="$name" '$0 == os {f=1; next} /^-- /{f=0} f && index($0, "    " name " (") == 1' \
      | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  fi
  echo "$udid"
}

pixel_size() {
  sips -g pixelWidth -g pixelHeight "$1" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w"x"h}'
}

# Boots the Duo, checks it is folded the way this platform needs (judged by whether the
# inner screen shows anything) and pins the status bar, which xcodebuild doesn't do for the
# clock in the Duo's side bar.
prepare_duo() {
  local platform=$1 destination=$2 udid shot bytes state
  udid=$(udid_for "$destination")
  if [ -z "$udid" ]; then
    echo "    FAILED — no iPhone Duo simulator for $destination"
    return 1
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1 || true
  # The inner screen is black while folded, which compresses to about 100KB as a PNG (a
  # screen with content is several MB). The default screen's size can't tell: unfolded, it
  # has come back as the outer screen turned sideways.
  shot="$WORK/duo-inner.png"
  xcrun simctl io "$udid" screenshot --display=primary-1 "$shot" > /dev/null 2>&1
  bytes=$(stat -f%z "$shot" 2>/dev/null || echo 0)
  state=folded
  [ "$bytes" -gt "$DUO_INNER_BLANK_MAX_BYTES" ] && state=unfolded
  case "$platform" in
    duo-open)
      if [ "$state" != unfolded ]; then
        echo "    FAILED — the Duo is folded. Unfold it with the button under the device in DeviceHub, then run again"
        return 1
      fi ;;
    duo-closed)
      if [ "$state" != folded ]; then
        echo "    FAILED — the Duo is unfolded. Fold it in DeviceHub or reboot the simulator, then run again"
        return 1
      fi ;;
  esac
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 \
    > /dev/null 2>&1 || true
}

# Drops the orientation metadata (eXIf and XMP) from a PNG. XCUIScreen's image carries
# "turn 90° when shown" (orientation 6); left in after the pixels are turned, it makes browsers
# and App Store Connect turn the image a second time.
strip_png_orientation() {
  python3 - "$1" <<'EXIF'
import struct, sys

path = sys.argv[1]
data = open(path, "rb").read()
out, i = [data[:8]], 8
while i < len(data):
    length, kind = struct.unpack(">I4s", data[i:i + 8])
    chunk = data[i:i + 12 + length]
    xmp = kind == b"iTXt" and data[i + 8:i + 8 + 17] == b"XML:com.adobe.xmp"
    if kind != b"eXIf" and not xmp:
        out.append(chunk)
    i += 12 + length
open(path, "wb").write(b"".join(out))
EXIF
}

# The unfolded Duo's inner screen comes back as a portrait-shaped framebuffer: turn it to
# landscape and size it to 2853x2007 (XCUIScreen's image is 1px short, 2006x2852).
normalize_duo_open() {
  local dest=$1 png size w h
  for png in "$dest"/*.png; do
    size=$(pixel_size "$png")
    w=${size%x*}; h=${size#*x}
    if [ "$w" -lt "$h" ]; then
      sips -r 90 "$png" > /dev/null
    fi
    if [ "$(pixel_size "$png")" != "$DUO_OPEN_SIZE" ]; then
      sips -z "${DUO_OPEN_SIZE#*x}" "${DUO_OPEN_SIZE%x*}" "$png" > /dev/null
    fi
    strip_png_orientation "$png"
  done
  echo "    normalized to $DUO_OPEN_SIZE"
}

capture_via_uitest() {
  local platform=$1 scheme=$2 testid=$3 destination=$4 locale=$5
  local bundle="$WORK/$platform-$locale.xcresult"
  local log="$WORK/$platform-$locale.log"
  rm -rf "$bundle"

  case "$platform" in
    duo-*)
      if ! prepare_duo "$platform" "$destination"; then
        failed+=("$platform/$locale")
        return
      fi ;;
  esac

  # Only for the unfolded Duo: have the test capture the inner screen (the test sees it
  # without the TEST_RUNNER_ prefix).
  local duo_open=0
  if [ "$platform" = "duo-open" ]; then
    duo_open=1
  fi

  # Parallel testing off: otherwise xcodebuild runs the tests on a clone of the simulator,
  # which loses the Duo's fold state (a clone always starts folded).
  #
  # -testLanguage / -testRegion, not -AppleLanguages launch arguments: this is what moves
  # `Locale.current` inside the app under test, which the fixture reads to pick its titles.
  if ! TEST_RUNNER_SCREENSHOT_DUO_OPEN=$duo_open xcodebuild test \
    -project IntentTodo.xcodeproj \
    -scheme "$scheme" \
    -destination "$destination" \
    -only-testing:"$testid" \
    -resultBundlePath "$bundle" \
    -testLanguage "$locale" \
    -testRegion "$(region_for "$locale")" \
    -parallel-testing-enabled NO \
    > "$log" 2>&1; then
    echo "    FAILED — see $log"
    failed+=("$platform/$locale")
    return
  fi

  local dest="$OUT/$platform/$locale"
  rm -rf "$dest" && mkdir -p "$dest"

  local staging="$WORK/$platform-$locale-attachments"
  rm -rf "$staging"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$staging" > /dev/null

  # The exported filenames are opaque; manifest.json maps them back to the names the test
  # gave each attachment.
  python3 - "$staging" "$dest" <<'PY'
import json, pathlib, re, shutil, sys

staging, dest = (pathlib.Path(p) for p in sys.argv[1:3])
manifest = json.loads((staging / "manifest.json").read_text())

# XCTest appends "_<index>_<uuid>" to the name the test gave the attachment.
SUFFIX = re.compile(r"_\d+_[0-9A-Fa-f-]{36}$")

count = 0
for test in manifest:
    for attachment in test.get("attachments", []):
        exported = attachment.get("exportedFileName")
        name = attachment.get("suggestedHumanReadableName") or exported
        if not exported:
            continue
        stem = SUFFIX.sub("", pathlib.Path(name).stem)
        shutil.copyfile(staging / exported, dest / f"{stem}.png")
        count += 1

if count == 0:
    sys.exit("no attachments in the result bundle")
print(f"    {count} screenshot(s) -> {dest}")
PY

  [ "$platform" = "mac" ] && normalize_mac "$dest"
  [ "$platform" = "duo-open" ] && normalize_duo_open "$dest"
  return 0
}

# App Store Connect only accepts a fixed set of Mac sizes, and a window capture lands a
# little off whatever the window was asked to be — the title bar is not part of the content.
# Scale to fit, then pad to the exact size with the window's own background colour.
normalize_mac() {
  local dest=$1 width height
  width=${MAC_WIDTH:-2880}
  height=${MAC_HEIGHT:-1800}
  python3 - "$dest" "$width" "$height" <<'PY'
import pathlib, subprocess, sys

dest, target_w, target_h = pathlib.Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])

def pixel_size(path):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                         capture_output=True, text=True).stdout
    values = {line.split(":")[0].strip(): int(line.split(":")[1])
              for line in out.splitlines() if ":" in line and "pixel" in line}
    return values["pixelWidth"], values["pixelHeight"]

for png in sorted(dest.glob("*.png")):
    width, height = pixel_size(png)
    # Fit inside the target rather than `sips -Z`, which only bounds the longer side and
    # then lets the pad step crop the other one — that is what cut the title bar off.
    scale = min(target_w / width, target_h / height)
    subprocess.run(["sips", "-z", str(round(height * scale)), str(round(width * scale)), str(png)],
                   capture_output=True)
    subprocess.run(["sips", "--padToHeightWidth", str(target_h), str(target_w),
                    "--padColor", "1C1C1E", str(png)], capture_output=True)
PY
  echo "    normalized to ${width}x${height}"
}

# --- Apple Vision Pro ----------------------------------------------------------------------

vision_udid() {
  # There is one device of this name per installed runtime, so the 27.0 section has to be
  # isolated before matching — otherwise an older runtime's device wins and the install
  # fails with "needs a newer version of iOS".
  xcrun simctl list devices available \
    | awk '/-- visionOS 27.0 --/{f=1;next} /^-- /{f=0} f && /Apple Vision Pro/' \
    | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

capture_vision() {
  local locale=$1
  local udid app dest log="$WORK/vision-$locale.log"

  udid=$(vision_udid)
  if [ -z "$udid" ]; then
    echo "    FAILED — no visionOS 27.0 'Apple Vision Pro' simulator"
    failed+=("vision/$locale")
    return
  fi

  if ! xcodebuild build -project IntentTodo.xcodeproj -scheme IntentTodo \
      -destination "platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0" \
      > "$log" 2>&1; then
    echo "    FAILED — build, see $log"
    failed+=("vision/$locale")
    return
  fi
  # Both values come from the same settings dump so a product rename cannot desync them.
  settings=$(xcodebuild -project IntentTodo.xcodeproj -scheme IntentTodo \
        -destination "platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0" \
        -showBuildSettings 2>/dev/null)
  app=$(echo "$settings" | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')/$(echo "$settings" | awk -F' = ' '/ FULL_PRODUCT_NAME = /{print $2; exit}')

  # Erased once per script run. `simctl io screenshot` captures the whole simulated room,
  # so anything the previous run left floating there — a stray system alert, a window that
  # was never closed — ends up in the shot. Only a fresh device reliably clears it.
  if [ -z "${vision_device_prepared:-}" ]; then
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    xcrun simctl erase "$udid"
    vision_device_prepared=1
  fi

  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b > /dev/null
  xcrun simctl install "$udid" "$app"

  dest="$OUT/vision/$locale"
  rm -rf "$dest" && mkdir -p "$dest"

  # One launch per screen. The alternative — one launch plus `simctl openurl` — fails
  # visibly: a URL arriving from outside puts an "Open in …?" confirmation over the shot.
  local screens=("01-list:list" "02-detail:detail" "03-add:add")
  for entry in "${screens[@]}"; do
    local name=${entry%%:*} screen=${entry##*:}
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    xcrun simctl launch "$udid" "$BUNDLE_ID" \
      -uitest-ephemeral-store -uitest-screenshot-fixture \
      -uitest-screenshot-screen "$screen" \
      -AppleLanguages "($locale)" -AppleLocale "${locale}_$(region_for "$locale")" > /dev/null
    sleep 12
    xcrun simctl io "$udid" screenshot "$dest/$name.png" > /dev/null 2>&1
  done

  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  echo "    ${#screens[@]} screenshot(s) -> $dest"
}

# --- Run -----------------------------------------------------------------------------------

for entry in "${UITEST_PLATFORMS[@]}"; do
  IFS='|' read -r platform scheme testid destination <<< "$entry"
  wanted "$platform" || continue
  for locale in $LOCALES; do
    echo "==> $platform / $locale"
    capture_via_uitest "$platform" "$scheme" "$testid" "$destination" "$locale"
  done
done

if wanted vision; then
  for locale in $LOCALES; do
    echo "==> vision / $locale"
    capture_vision "$locale"
  done
fi

echo
echo "=== sizes ==="
find "$OUT" -name "*.png" | sort | while read -r png; do
  size=$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w"x"h}')
  printf '%-56s %s\n' "${png#"$OUT"/}" "$size"
done

echo
if [ ${#failed[@]} -gt 0 ]; then
  echo "FAILED: ${failed[*]}"
  echo "Logs are in $WORK"
  exit 1
fi
echo "All captures succeeded. Open with: open $OUT"
