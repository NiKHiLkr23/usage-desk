#!/bin/zsh
# No upload or publication. Default packages a clearly labelled local review build.
set -euo pipefail
task_root="${0:A:h:h}"
cd "$task_root"
mode="preview"
universal=false
for option in "$@"; do
  case "$option" in
    --release) mode="release" ;;
    --universal) universal=true ;;
    *) print -u2 "Usage: scripts/package.sh [--release] [--universal]"; exit 2 ;;
  esac
done
if [[ "$mode" == "release" ]]; then
  : "${USAGE_DESK_SIGNING_IDENTITY:?Set a Developer ID Application identity already in Keychain}"
  : "${USAGE_DESK_NOTARY_PROFILE:?Set a notarytool Keychain profile name}"
  zsh scripts/build.sh --universal
elif $universal; then
  zsh scripts/build.sh --universal
else
  zsh scripts/build.sh
fi
app_dir="$task_root/dist/Usage desk.app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
architecture="$(lipo -archs "$app_dir/Contents/MacOS/ResetDesk")"
if [[ "$architecture" == *arm64* && "$architecture" == *x86_64* ]]; then architecture="universal"; fi
mkdir -p "$task_root/dist/releases"
archive="$task_root/dist/releases/usage-desk-$version-macos-$architecture.zip"
if [[ "$mode" == "release" ]]; then
  codesign --force --options runtime --timestamp --sign "$USAGE_DESK_SIGNING_IDENTITY" "$app_dir"
  codesign --verify --strict "$app_dir"
  # This mode is an explicit maintainer action; it submits only the app archive to Apple.
  submission="$task_root/dist/releases/notarization-submission.zip"
  ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$submission"
  xcrun notarytool submit "$submission" --keychain-profile "$USAGE_DESK_NOTARY_PROFILE" --wait
  xcrun stapler staple "$app_dir"
  xcrun stapler validate "$app_dir"
  spctl --assess --type execute --verbose "$app_dir"
fi
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
(cd "${archive:h}" && shasum -a 256 "${archive:t}") > "$archive.sha256"

print "Packaged: $archive"
print "No GitHub release, upload, commit, or push was performed."
