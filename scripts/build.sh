#!/bin/zsh
set -euo pipefail
task_root="${0:A:h:h}"
cd "$task_root"
demo=false
universal=false
for option in "$@"; do
  case "$option" in
    --demo) demo=true ;;
    --universal) universal=true ;;
    *) print -u2 "Usage: scripts/build.sh [--demo] [--universal]"; exit 2 ;;
  esac
done
swift_arch=()
if $universal; then swift_arch=(--arch arm64 --arch x86_64); fi
export CLANG_MODULE_CACHE_PATH="$task_root/.cache/modules"
export SWIFT_MODULECACHE_PATH="$task_root/.cache/modules"
swift build -c release "${swift_arch[@]}" --scratch-path "$task_root/.build" --cache-path "$task_root/.cache" -Xswiftc -module-cache-path -Xswiftc "$task_root/.cache/modules"
binary_dir="$(swift build -c release "${swift_arch[@]}" --show-bin-path --scratch-path "$task_root/.build")"
app_name="Usage desk"
if $demo; then app_name="Usage Desk Demo"; fi
app_dir="$task_root/dist/$app_name.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/ResetDesk" "$app_dir/Contents/MacOS/ResetDesk"
cp "$task_root/Support/Info.plist" "$app_dir/Contents/Info.plist"
cp "$task_root/assets/brand/UsageDesk.icns" "$app_dir/Contents/Resources/UsageDesk.icns"
if $demo; then
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier in.nikhilkr.resetdesk.demo' "$app_dir/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName Usage Desk Demo' "$app_dir/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Add :UsageDeskDemo bool true' "$app_dir/Contents/Info.plist"
fi
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
print "Built $app_dir"
