#!/bin/bash
# PROJECT SATYA: MASTER BUILD SYSTEM
# =====================================
# PHASE: 6.8 (Forensic Synchronization)
# VERSION: 1.6.8
# STATUS: STABLE (No Poisoning)

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# --- CONFIG ---
ANDROID_SDK_ROOT="/Volumes/Apple/Android/sdk"
NDK_VERSION="28.2.13676358" 
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
ROOT_DIR=$(pwd)

# --- CLEAN ENVIRONMENT FOR FFI ---
unset SDKROOT
unset CPATH
unset C_INCLUDE_PATH

echo -e "${BLUE}>>> [1/3] FFI Sync (Codegen)...${NC}"
flutter_rust_bridge_codegen \
    --rust-input rust_core/src/api.rs \
    --dart-output flutter_app/lib/bridge_generated.dart \
    --rust-output rust_core/src/bridge_generated.rs \
    --rust-crate-dir rust_core || { echo -e "${RED}Sync Failed${NC}"; exit 1; }

cd rust_core || exit 1

# --- ANDROID (Strictly Scoped) ---
echo "Building Android Binaries..."
cargo ndk -t arm64-v8a -o "$ROOT_DIR/flutter_app/android/app/src/main/jniLibs" build --release || exit 1

# --- iOS ---
echo "Building iOS Static Libs..."
cargo build --release --target aarch64-apple-ios-sim || exit 1
cp "target/aarch64-apple-ios-sim/release/librust_core.a" "$ROOT_DIR/flutter_app/ios/Runner/librust_core.a"

# --- macOS (Scoped) ---
echo "Building macOS Native (.dylib)..."
# Apply Mac headers ONLY for this specific block
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export CPATH="$SDKROOT/usr/include"
cargo build --release --target aarch64-apple-darwin || exit 1
unset SDKROOT CPATH

echo "Deploying to Flutter App..."
cp "target/aarch64-apple-darwin/release/librust_core.dylib" "$ROOT_DIR/flutter_app/macos/librust_core.dylib"
cp "target/aarch64-apple-darwin/release/librust_core.dylib" "$ROOT_DIR/flutter_app/librust_core.dylib"

# Post-build copy to app bundle (ensures library is always available)
if [ -f "$ROOT_DIR/flutter_app/copy_rust_lib.sh" ]; then
  echo "Copying Rust library to app bundle..."
  cd "$ROOT_DIR/flutter_app" && ./copy_rust_lib.sh
fi

echo -e "${GREEN}✓ Phase 6.8 Trinity Build Successful.${NC}"
exit 0
