#!/bin/bash
# Adding Persistence and Security: Zero-Error Build Factory
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# --- CONFIG ---
ANDROID_SDK_ROOT="/Volumes/Apple/Android/sdk"
NDK_VERSION="28.2.13676358" 
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
ROOT_DIR=$(pwd)

# --- MAC HEADER RESOLVER (Fixes stdlib.h issue) ---
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export C_INCLUDE_PATH="$SDKROOT/usr/include"
export CPATH="$SDKROOT/usr/include"

echo -e "${BLUE}>>> Synchronizing FFI Bridge (With Native Headers)...${NC}"
# Forcing clean generation to fix the crash
flutter_rust_bridge_codegen \
    --rust-input rust_core/src/api.rs \
    --dart-output flutter_app/lib/bridge_generated.dart \
    --rust-output rust_core/src/bridge_generated.rs \
    --rust-crate-dir rust_core || { echo -e "${RED}Bridge Sync Failed${NC}"; exit 1; }

echo -e "${BLUE}>>> Compiling Phase 3 Rust Core...${NC}"
cd rust_core || exit 1

# --- ANDROID ---
echo "Building Android Binaries..."
cargo ndk -t arm64-v8a -o "$ROOT_DIR/flutter_app/android/app/src/main/jniLibs" build --release || exit 1
cargo ndk -t armeabi-v7a -o "$ROOT_DIR/flutter_app/android/app/src/main/jniLibs" build --release || exit 1

# --- iOS ---
echo "Building iOS Binaries..."
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios || exit 1
cargo build --release --target aarch64-apple-ios-sim || exit 1
cargo build --release --target x86_64-apple-ios || exit 1

echo "Stitching Universal iOS Binary..."
mkdir -p target/universal/release
lipo -create \
    target/x86_64-apple-ios/release/librust_core.a \
    target/aarch64-apple-ios-sim/release/librust_core.a \
    -output target/universal/release/librust_core.a || exit 1

cp "target/universal/release/librust_core.a" "$ROOT_DIR/flutter_app/ios/Runner/librust_core.a"

echo -e "${GREEN}✓ Phase 3 Successfully Baselined with Clean Headers.${NC}"
exit 0
