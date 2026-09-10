#!/bin/bash
#
# Captures the App Store submission screenshots for every platform and locale.
#
#   ./scripts/capture_screenshots.sh                 # everything
#   ./scripts/capture_screenshots.sh iphone ipad     # only these platforms
#   LOCALES="ja" ./scripts/capture_screenshots.sh    # only this locale
#
# Output goes to Screenshots/<platform>/<locale>/NN-name.png (gitignored).
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

# platform | scheme | test target/class | destination
#
# macOS is deliberately absent from the default set — pass `mac` explicitly to try it. The
# run does not produce usable images yet (#127): the sidebar row is a single accessibility
# element that cannot be navigated from, and the window comes back at an arbitrary size
# rather than one App Store Connect accepts.
PLATFORMS=(
  "iphone|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0"
  "ipad|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0"
  "vision|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0"
  "watch|IntentTodoWatchAppUITest|IntentTodoWatchAppUITest/WatchScreenshotTests|platform=watchOS Simulator,name=Apple Watch Ultra 4 (49mm),OS=27.0"
)
MAC_PLATFORM="mac|IntentTodoUITest|IntentTodoUITest/ScreenshotTests|platform=macOS,arch=arm64"
for name in "$@"; do
  [ "$name" = "mac" ] && PLATFORMS+=("$MAC_PLATFORM")
done

requested=("$@")

wanted() {
  [ ${#requested[@]} -eq 0 ] && return 0
  for name in "${requested[@]}"; do
    [ "$name" = "$1" ] && return 0
  done
  return 1
}

mkdir -p "$WORK"
failed=()

for entry in "${PLATFORMS[@]}"; do
  IFS='|' read -r platform scheme testid destination <<< "$entry"
  wanted "$platform" || continue

  for locale in $LOCALES; do
    echo "==> $platform / $locale"
    bundle="$WORK/$platform-$locale.xcresult"
    log="$WORK/$platform-$locale.log"
    rm -rf "$bundle"

    case "$locale" in
      ja) region=JP ;;
      *)  region=US ;;
    esac

    # -testLanguage / -testRegion, not -AppleLanguages launch arguments: this is what moves
    # `Locale.current` inside the app under test, which the fixture reads to pick its titles.
    if ! xcodebuild test \
      -project IntentTodo.xcodeproj \
      -scheme "$scheme" \
      -destination "$destination" \
      -only-testing:"$testid" \
      -resultBundlePath "$bundle" \
      -testLanguage "$locale" \
      -testRegion "$region" \
      > "$log" 2>&1; then
      echo "    FAILED — see $log"
      failed+=("$platform/$locale")
      continue
    fi

    dest="$OUT/$platform/$locale"
    rm -rf "$dest"
    mkdir -p "$dest"

    staging="$WORK/$platform-$locale-attachments"
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
  done
done

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
