#!/bin/bash
# FILE: fix_ios_rust.sh
# ROLE: Build Rust library for iOS architecture and prep for Xcode linking

# 1. Setup Variables & Auto-detect Rust Directory
echo ">>> SATYA SETU: LOCATING RUST PROJECT"

# Search Priority:
# 1. Inside current folder (./native or ./rust)
# 2. Inside parent folder (../native or ../rust)

FOUND_CARGO=$(find . -maxdepth 2 -name Cargo.toml | head -n 1)

if [ -z "$FOUND_CARGO" ]; then
    echo "   ... Not found in current folder. Checking parent folder..."
    FOUND_CARGO=$(find .. -maxdepth 2 -name Cargo.toml | head -n 1)
fi

if [ -n "$FOUND_CARGO" ]; then
    # Get directory containing Cargo.toml
    RUST_DIR=$(dirname "$FOUND_CARGO")
else
    echo "❌ Error: Could not find a Rust project (Cargo.toml)."
    echo "   Checked: $(pwd) and parent directory."
    echo "   Please ensure your 'native' or 'rust' folder exists nearby."
    exit 1
fi

echo "✅ Found Rust project in: $RUST_DIR"

LIB_NAME="libsatya_setu.a" # Standard name for Xcode
# Try to detect crate name from Cargo.toml
CRATE_NAME=$(grep -m 1 "name =" "$RUST_DIR/Cargo.toml" | cut -d '"' -f 2)
if [ -z "$CRATE_NAME" ]; then
    CRATE_NAME="satya_setu" # Fallback
fi

echo ">>> SATYA SETU: BUILDING RUST FOR IOS ($CRATE_NAME)"

# 2. Add iOS Architectures
echo "[1/4] Adding iOS Rust targets..."
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim # For Simulator

# 3. Build for iPhone (Physical Device)
echo "[2/4] Compiling Rust for iPhone (Release mode)..."
# Save current directory
PROJECT_ROOT=$(pwd)

cd "$RUST_DIR"
# Build static library
cargo build --target aarch64-apple-ios --release
cd "$PROJECT_ROOT"

# 4. Copy to iOS Runner
echo "[3/4] Copying library to Xcode project..."
SOURCE_LIB="$RUST_DIR/target/aarch64-apple-ios/release/lib$CRATE_NAME.a"
DEST_DIR="ios/Runner"

if [ -f "$SOURCE_LIB" ]; then
    cp "$SOURCE_LIB" "$DEST_DIR/$LIB_NAME"
    echo "✅ Success! Copied to $DEST_DIR/$LIB_NAME"
else
    echo "❌ Error: Built library not found at $SOURCE_LIB"
    echo "Check if your Cargo.toml has 'staticlib' crate-type."
    exit 1
fi

# 5. Open Xcode for Linking Instructions
echo "[4/4] Opening Xcode..."
open ios/Runner.xcworkspace

echo ""
echo "=========================================================="
echo "⚠️  CRITICAL STEP REQUIRED IN XCODE ⚠️"
echo "=========================================================="
echo "The library '$LIB_NAME' is now in your ios/Runner folder,"
echo "but Xcode doesn't know about it yet."
echo ""
echo "1. In Xcode, right-click the yellow 'Runner' folder (left sidebar)."
echo "2. Choose 'Add Files to \"Runner\"...'."
echo "3. Select '$LIB_NAME' from the list and click 'Add'."
echo "   (If you don't see it, look inside the ios/Runner folder on disk)."
echo ""
echo "4. Click the blue 'Runner' project icon (top left)."
echo "5. Select the 'Runner' TARGET (not Project)."
echo "6. Go to 'Build Phases' -> 'Link Binary With Libraries'."
echo "7. If '$LIB_NAME' is not there, drag it from the sidebar into this list."
echo ""
echo "8. Run the app again on your phone!"
echo "=========================================================="