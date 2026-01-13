#!/bin/bash
# FILE: run_signed.sh
# ROLE: Clean, Install Dependencies, and Open Xcode for Manual Signing

echo ">>> SATYA SETU: PREPARING IOS ENVIRONMENT"

# 1. Deep Clean to remove old build artifacts
echo "[1/4] Scrubbing build cache..."
cd flutter_app
flutter clean
flutter pub get

# 2. Update iOS Dependencies
echo "[2/4] Installing iOS Pods..."
cd ios
rm -f Podfile.lock
pod install --repo-update
cd ..

# 3. Open Xcode
echo "[3/4] Opening project in Xcode..."
# This opens the workspace, which is required for CocoaPods
open ios/Runner.xcworkspace

# 4. Instructions
echo ""
echo "=========================================================="
echo "ACTION REQUIRED: XCODE IS NOW OPEN"
echo "=========================================================="
echo "1. In Xcode, click the blue 'Runner' icon on the left."
echo "2. Go to the 'Signing & Capabilities' tab."
echo "3. Check 'Automatically manage signing'."
echo "4. Select YOUR NAME (Personal Team) in the Team dropdown."
echo "5. Ensure the Bundle Identifier is unique (e.g., com.yourname.satyasetu)."
echo "6. Click the PLAY button (▶) in the top-left to run."
echo "=========================================================="