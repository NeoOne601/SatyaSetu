#!/bin/bash
# FILE: fix_ios_build.sh
# ROLE: Surgical Fix for iOS Physical Device Linking Error

echo ">>> SATYA SETU: iOS PHYSICAL DEVICE PATCH"

# 1. Navigate to Rust Core
cd rust_core

# 2. Add the Apple iOS Physical Target (ARM64)
echo "[1/3] Installing iOS toolchain..."
rustup target add aarch64-apple-ios

# 3. Build specifically for iPhone
# This ensures the binary is compatible with iPhone 11 Pro (ARM64)
echo "[2/3] Compiling Rust Core for Physical Device..."
cargo build --release --target aarch64-apple-ios

# 4. Patch the Universal Path
# Xcode is looking in 'target/universal/release', so we put the correct file there.
# NOTE: This replaces any Simulator build with the Physical Device build.
echo "[3/3] Patching Xcode linker path..."
mkdir -p target/universal/release
cp target/aarch64-apple-ios/release/librust_core.a target/universal/release/librust_core.a

echo "✅ SUCCESS: Rust Core patched for iPhone 11 Pro."
echo "👉 You may now run 'flutter run' in the flutter_app directory."
