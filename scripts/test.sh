#!/bin/bash
# Runs the fast core tests (no simulator). Pass --ui to also run the simulator UI test.
set -euo pipefail
cd "$(dirname "$0")/.."

swift test

if [[ "${1:-}" == "--ui" ]]; then
  : "${SIMULATOR_NAME:?Set SIMULATOR_NAME to an installed simulator, e.g. SIMULATOR_NAME='iPhone 17'}"
  xcodegen generate
  xcodebuild test \
    -project Hisaab.xcodeproj \
    -scheme Hisaab \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
    -derivedDataPath build/DerivedData
fi
