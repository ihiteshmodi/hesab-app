#!/bin/bash
# Builds an unsigned build/Hisaab.ipa for sideloading (for example with LiveContainer).
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild build \
  -project Hisaab.xcodeproj \
  -scheme Hisaab \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

rm -rf build/ipa build/Hisaab.ipa
mkdir -p build/ipa/Payload
cp -R build/DerivedData/Build/Products/Release-iphoneos/Hisaab.app build/ipa/Payload/
(cd build/ipa && zip -qry ../Hisaab.ipa Payload)
echo "Built build/Hisaab.ipa"
