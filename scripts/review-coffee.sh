#!/bin/zsh
# Render isolated native studies or open the comparison window. Never uses accounts.
set -euo pipefail
task_repo="${0:A:h:h}"
task_review="$task_repo/.local/coffee-review"
mkdir -p "$task_review/Sources"
cp "$task_repo/Package.swift" "$task_review/Package.swift"
cp -R "$task_repo/Tests" "$task_review/"
cp -R "$task_repo/Sources/ResetDesk" "$task_review/Sources/"
cp -R "$task_repo/Sources/ResetDeskCore" "$task_review/Sources/"
python3 - "$task_review/Sources/ResetDesk/ResetDeskApp.swift" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();assert '@main struct ResetDeskApp: App' in s
p.write_text(s.replace('@main struct ResetDeskApp: App','struct ResetDeskApp: App'))
PY
cp "$task_repo/scripts/review-coffee.swift" "$task_review/Sources/ResetDesk/CoffeeReview.swift"
cd "$task_review"
export CLANG_MODULE_CACHE_PATH="$task_review/.cache/modules"
export SWIFT_MODULECACHE_PATH="$task_review/.cache/modules"
swift build --disable-sandbox -c release --scratch-path .build --cache-path .cache -Xswiftc -module-cache-path -Xswiftc .cache/modules
if [[ "${1:-}" == --interactive || "${1:-}" == --build-only ]]; then
  app_dir="$task_review/Usage Desk Coffee Review.app"
  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp .build/release/ResetDesk "$app_dir/Contents/MacOS/CoffeeReview"
  cp -R .build/release/ResetDesk_ResetDesk.bundle "$app_dir/Contents/Resources/"
  cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>in.nikhilkr.usagedesk.coffee-review</string><key>CFBundleName</key><string>Usage Desk Coffee Review</string><key>CFBundleExecutable</key><string>CoffeeReview</string><key>CFBundlePackageType</key><string>APPL</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
  codesign --force --sign - "$app_dir"
  if [[ "${1:-}" == --interactive ]]; then
    open -n "$app_dir" --args --interactive
  else
    print "Built isolated comparison app: $app_dir"
  fi
else
  .build/release/ResetDesk "$@"
fi
