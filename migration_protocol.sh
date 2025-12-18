#!/bin/bash

# SATYA MIGRATION PROTOCOL
# Purpose: Clean artifacts, Move Source to Internal, Keep SDKs External

EXTERNAL_DIR="/Volumes/Apple/Development/SatyaSetu_Monorepo"
INTERNAL_DIR="$HOME/Documents/SatyaSetu_Internal"

echo "=== PHASE 1: COMPACTING EXTERNAL PROJECT ==="
cd "$EXTERNAL_DIR" || exit 1

# 1. Clean Flutter (Removes /build)
cd flutter_app
flutter clean
rm -rf ios/Pods
rm -rf ios/Runner.xcworkspace
rm ios/Podfile.lock
cd ..

# 2. Clean Rust (Removes /target - HUGE SAVINGS)
echo "Cleaning Rust Artifacts (This saves ~1.5GB)..."
cd rust_core
cargo clean
cd ..

# 3. Clean Symlinks/Temp files
rm -rf flutter_app/.dart_tool
rm -rf flutter_app/ios/.symlinks

echo "=== PHASE 2: EXECUTING MIGRATION ==="
# Create Internal Directory
mkdir -p "$INTERNAL_DIR"

# Copy ONLY the source code (Recursive)
echo "Transferring Source Code to Internal Drive..."
cp -R . "$INTERNAL_DIR"

echo "=== MIGRATION COMPLETE ==="
echo "New Project Location: $INTERNAL_DIR"
echo "SDKs remain on External Drive (Safe)."
