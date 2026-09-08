#!/usr/bin/env bash
# Build Telecine for the iOS Simulator (default) or tvOS Simulator (`build.sh tv`).
# Regenerates the Xcode project from project.yml first. Derived data lives outside the repo:
# ~/Documents is an iCloud file-provider domain and codesign refuses packages it has stamped.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodegen generate --quiet
DD="${TELECINE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Telecine-scripts}"
mkdir -p "$DD" build
if [[ "${1:-ios}" == "tv" ]]; then
  SCHEME=TelecineTV
  TV_UDID="${TELECINE_TV_UDID:-$(xcrun simctl list devices available | grep 'Apple TV 4K (3rd generation) (' | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')}"
  DEST="platform=tvOS Simulator,id=$TV_UDID"
else SCHEME=Telecine; DEST='generic/platform=iOS Simulator'; fi
for attempt in 1 2 3; do
  if xcodebuild -project Telecine.xcodeproj -scheme "$SCHEME" -destination "$DEST" -derivedDataPath "$DD" \
       CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build/last-build.log | grep -E "error:|warning: .*Telecine/|BUILD (SUCCEEDED|FAILED)"; then
    grep -q "BUILD SUCCEEDED" build/last-build.log && exit 0
  fi
  grep -q "error:" build/last-build.log && exit 1
  echo "build attempt $attempt failed; retrying" >&2; sleep 5
done
exit 1
