#!/usr/bin/env bash
# Run the engine tests (the ported reference suite + parity with src/lib/broadcast.js).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodegen generate --quiet
DD="${TELECINE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Telecine-scripts}"
DEVICE="${TELECINE_DEVICE:-iPhone 17 Pro}"
mkdir -p build
xcodebuild -project Telecine.xcodeproj -scheme Telecine -destination "platform=iOS Simulator,name=$DEVICE" -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee build/last-test.log | grep -E "error:|Test Suite|Test Case.*(passed|failed)|✔|✘|Executed|TEST (SUCCEEDED|FAILED)" | tail -40
grep -q "TEST SUCCEEDED" build/last-test.log
