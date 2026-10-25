#!/bin/zsh
# Render the real app's SwiftUI views with isolated sample data. No app launch or live accounts.
set -euo pipefail
task_repo="${0:A:h:h}"
task_capture_root=$(mktemp -d /tmp/usage-desk-website-capture.XXXXXX)
trap 'rm -rf -- "$task_capture_root"' EXIT
# Use the reviewed, committed native code, never local account storage or ignored files.
git -C "$task_repo" archive HEAD | tar -x -C "$task_capture_root"
node --input-type=module - "$task_capture_root" <<'JS'
import {readFile,writeFile} from 'node:fs/promises';
import path from 'node:path';
const file=path.join(process.argv[2],'Sources/ResetDesk/ResetDeskApp.swift');
const source=await readFile(file,'utf8');
if(!source.includes('@main struct ResetDeskApp: App'))throw new Error('App entry point changed; review the capture tool.');
// Hide only the presentation badge in the temporary render. Demo data and safety guards remain active.
const badge='                if store.isDemo { Text("Demo").font(.system(size: 9, weight: .medium)).foregroundStyle(DeskTheme.muted) }';
if(!source.includes(badge))throw new Error('Demo badge changed; review the capture tool.');
await writeFile(file,source.replace('@main struct ResetDeskApp: App','struct ResetDeskApp: App').replace(badge+'\n',''));
JS
cp "$task_repo/scripts/capture-website.swift" "$task_capture_root/Sources/ResetDesk/ProductCapture.swift"
cd "$task_capture_root"
swift build -c release --scratch-path .build --cache-path .cache -Xswiftc -module-cache-path -Xswiftc .cache/modules
.build/release/ResetDesk "$task_capture_root/captures"
mkdir -p "$task_repo/assets/screenshots/native"
cp "$task_capture_root"/captures/showcase-*.png "$task_repo/assets/screenshots/native/"
print 'Captured native app views using sample data. Inspect the three images before publishing.'
