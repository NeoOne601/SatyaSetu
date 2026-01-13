#!/bin/bash
# FILE: fix_ios_build.sh
# ROLE: Surgical Fix for iPhone 11 Pro (Physical Device FORCE Mode)
# NOTE: This disables Simulator support temporarily to unblock physical deployment.

echo ">>> SATYA SETU: iOS PHYSICAL DEVICE PATCH (FORCE MODE)"

# 1. Setup & Clean
cd rust_core
echo "[1/4] Cleaning Rust build artifacts..."
cargo clean

# 2. Add Target
echo "[2/4] Ensuring iOS Physical target is installed..."
rustup target add aarch64-apple-ios

# 3. Build ONLY for Physical Device
echo "[3/4] Compiling Rust for iPhone (arm64)..."
cargo build --release --target aarch64-apple-ios

# 4. DIRECT INJECTION (No Lipo)
# We take the physical device build and put it exactly where Xcode looks.
# We also create the 'universal' folder structure just to satisfy any path expectations,
# even though the file inside is technically "thin" (arm64 only).
echo "[4/4] Injecting iPhone binary..."

# Ensure destination exists
mkdir -p ../flutter_app/ios/Runner
mkdir -p target/universal/release

# Copy to the Rust target folder (for script consistency)
cp target/aarch64-apple-ios/release/librust_core.a target/universal/release/librust_core.a

# Copy directly to Flutter project
cp target/aarch64-apple-ios/release/librust_core.a ../flutter_app/ios/Runner/librust_core.a

echo "✅ SUCCESS: iPhone binary injected."
echo "👉 Run 'flutter clean' then 'flutter run' in flutter_app."