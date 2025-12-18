#!/bin/bash

# SATYA BUILD FACTORY (Migration Edition)
# Context: Running on INTERNAL Drive (~/Documents)
# Resources: Using NDK on EXTERNAL Drive (/Volumes/Apple)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# --- 1. BRIDGE CONFIGURATION ---
# We point to the External Drive for heavy tools
ANDROID_SDK_ROOT="/Volumes/Apple/Android/sdk"
NDK_VERSION="28.2.13676358" 
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"

echo -e "${BLUE}=== INITIATING MIGRATION BUILD FACTORY ===${NC}"
echo "Context: Internal Drive ($(pwd))"
echo "Toolchain: External Drive ($ANDROID_NDK_HOME)"

# --- 2. SETUP LOCAL PATHS ---
ROOT_DIR=$(pwd)
ANDROID_JNI_DIR="$ROOT_DIR/flutter_app/android/app/src/main/jniLibs"
IOS_FLUTTER_DIR="$ROOT_DIR/flutter_app/ios/Runner"

# --- PART A: ANDROID COMPILATION ---
echo -e "${BLUE}>>> Building for Android...${NC}"

if [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo -e "${RED}ERROR: External NDK not found at $ANDROID_NDK_HOME${NC}"
    echo "Ensure the External Drive 'Apple' is mounted."
    exit 1
fi

mkdir -p "$ANDROID_JNI_DIR/arm64-v8a"
mkdir -p "$ANDROID_JNI_DIR/armeabi-v7a"
mkdir -p "$ANDROID_JNI_DIR/x86_64"

cd rust_core

echo "Compiling arm64-v8a..."
cargo ndk -t arm64-v8a -o "$ANDROID_JNI_DIR" build --release || exit 1

echo "Compiling armeabi-v7a..."
cargo ndk -t armeabi-v7a -o "$ANDROID_JNI_DIR" build --release || exit 1

echo "Compiling x86_64..."
cargo ndk -t x86_64 -o "$ANDROID_JNI_DIR" build --release || exit 1

echo -e "${GREEN}✓ Android Binaries Placed in jniLibs${NC}"


# --- PART B: iOS COMPILATION ---
echo -e "${BLUE}>>> Building for iOS...${NC}"

# Ensure targets exist
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# 1. Build for Device (ARM64)
echo "Compiling for iPhone Device (arm64)..."
cargo build --release --target aarch64-apple-ios || exit 1

# 2. Build for Simulator (ARM64)
echo "Compiling for Simulator (arm64)..."
cargo build --release --target aarch64-apple-ios-sim || exit 1

# 3. Build for Simulator (x86_64 - Intel)
echo "Compiling for Simulator (x86_64)..."
cargo build --release --target x86_64-apple-ios || exit 1

# 4. Create Universal Library using Lipo
echo "Stitching Universal Library..."
mkdir -p target/universal/release

# Combine x86 and arm64-sim into one "Fat" library for Simulators
lipo -create \
    target/x86_64-apple-ios/release/librust_core.a \
    target/aarch64-apple-ios-sim/release/librust_core.a \
    -output target/universal/release/librust_core.a || exit 1

# 5. Deployment
echo "Deploying Universal Simulator Library..."
mkdir -p "$IOS_FLUTTER_DIR"
cp "target/universal/release/librust_core.a" "$IOS_FLUTTER_DIR/librust_core.a"

echo -e "${GREEN}✓ Universal iOS Library Placed in ios/Runner${NC}"

cd "$ROOT_DIR"
echo -e "${BLUE}=== FACTORY SHUTDOWN. BUILD COMPLETE. ===${NC}"#!/bin/bash

# SATYA MOBILE BUILD FACTORY (Universal Edition - Verified)
# Architects: Larry Page & Sergey Brin
# Purpose: Cross-compile Rust Core for Android (.so) and iOS Universal (.a)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# --- CONFIGURATION ---
# Assuming SDK is at /Volumes/Apple/Android/sdk based on previous checks
ANDROID_SDK_ROOT="/Volumes/Apple/Android/sdk"

# UPDATE: Using the specific stable version confirmed via 'ls -la'
NDK_VERSION="28.2.13676358" 
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"

echo -e "${BLUE}=== INITIATING MOBILE FACTORY ===${NC}"
echo "Using NDK at: $ANDROID_NDK_HOME"

# 1. SETUP PATHS
ROOT_DIR=$(pwd)
ANDROID_JNI_DIR="$ROOT_DIR/flutter_app/android/app/src/main/jniLibs"
IOS_FLUTTER_DIR="$ROOT_DIR/flutter_app/ios/Runner"

# --- PART A: ANDROID COMPILATION ---
echo -e "${BLUE}>>> Building for Android...${NC}"

if [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo -e "${RED}ERROR: NDK not found at $ANDROID_NDK_HOME${NC}"
    echo "Double check the NDK_VERSION in this script matches a folder in /Volumes/Apple/Android/sdk/ndk/"
    exit 1
fi

mkdir -p "$ANDROID_JNI_DIR/arm64-v8a"
mkdir -p "$ANDROID_JNI_DIR/armeabi-v7a"
mkdir -p "$ANDROID_JNI_DIR/x86_64"

cd rust_core

echo "Compiling arm64-v8a..."
cargo ndk -t arm64-v8a -o "$ANDROID_JNI_DIR" build --release || exit 1

echo "Compiling armeabi-v7a..."
cargo ndk -t armeabi-v7a -o "$ANDROID_JNI_DIR" build --release || exit 1

echo "Compiling x86_64..."
cargo ndk -t x86_64 -o "$ANDROID_JNI_DIR" build --release || exit 1

echo -e "${GREEN}✓ Android Binaries Placed in jniLibs${NC}"


# --- PART B: iOS COMPILATION ---
echo -e "${BLUE}>>> Building for iOS...${NC}"

# Ensure targets exist (Fixes the "can't find crate for core" error)
echo "Ensuring Rust targets are installed..."
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# 1. Build for Device (ARM64)
echo "Compiling for iPhone Device (arm64)..."
cargo build --release --target aarch64-apple-ios || exit 1

# 2. Build for Simulator (ARM64)
echo "Compiling for Simulator (arm64)..."
cargo build --release --target aarch64-apple-ios-sim || exit 1

# 3. Build for Simulator (x86_64 - Intel)
echo "Compiling for Simulator (x86_64)..."
cargo build --release --target x86_64-apple-ios || exit 1

# 4. Create Universal Library using Lipo
echo "Stitching Universal Library..."
mkdir -p target/universal/release

# Combine x86 and arm64-sim into one "Fat" library for Simulators
lipo -create \
    target/x86_64-apple-ios/release/librust_core.a \
    target/aarch64-apple-ios-sim/release/librust_core.a \
    -output target/universal/release/librust_core.a || exit 1

# 5. Deployment
echo "Deploying Universal Simulator Library..."
# Ensure destination exists (flutter create might have reset it)
mkdir -p "$IOS_FLUTTER_DIR"
cp "target/universal/release/librust_core.a" "$IOS_FLUTTER_DIR/librust_core.a"

echo -e "${GREEN}✓ Universal iOS Library Placed in ios/Runner${NC}"

cd "$ROOT_DIR"
echo -e "${BLUE}=== FACTORY SHUTDOWN. BUILD COMPLETE. ===${NC}"#!/bin/bash

# SATYA MOBILE BUILD FACTORY (Universal Edition - Patched)
# Architects: Larry Page & Sergey Brin
# Purpose: Cross-compile Rust Core for Android (.so) and iOS Universal (.a)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# --- CONFIGURATION (CORRECTED FROM TERMINAL OUTPUT) ---
# Assuming SDK is at /Volumes/Apple/Android/sdk
ANDROID_SDK_ROOT="/Volumes/Apple/Android/sdk"

# UPDATE: Using the specific stable version confirmed via 'ls -la'
NDK_VERSION="28.2.13676358" 
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"

echo -e "${BLUE}=== INITIATING MOBILE FACTORY ===${NC}"
echo "Using NDK at: $ANDROID_NDK_HOME"

# 1. SETUP PATHS
ROOT_DIR=$(pwd)
ANDROID_JNI_DIR="$ROOT_DIR/flutter_app/android/app/src/main/jniLibs"
IOS_FLUTTER_DIR="$ROOT_DIR/flutter_app/ios/Runner"

# --- PART A: ANDROID COMPILATION ---
echo -e "${BLUE}>>> Building for Android...${NC}"

if [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo -e "${RED}ERROR: NDK not found at $ANDROID_NDK_HOME${NC}"
    echo "Double check the NDK_VERSION in this script matches a folder in /Volumes/Apple/Android/sdk/ndk/"
    exit 1
fi

mkdir -p "$ANDROID_JNI_DIR/arm64-v8a"
mkdir -p "$ANDROID_JNI_DIR/armeabi-v7a"
mkdir -p "$ANDROID_JNI_DIR/x86_64"

cd rust_core

echo "Compiling arm64-v8a..."
cargo ndk -t arm64-v8a -o "$ANDROID_JNI_DIR" build --release || exit 1

echo "Compiling armeabi-v7a..."
cargo ndk -t armeabi-v7a -o "$ANDROID_JNI_DIR" build --release || exit 1

echo "Compiling x86_64..."
cargo ndk -t x86_64 -o "$ANDROID_JNI_DIR" build --release || exit 1

echo -e "${GREEN}✓ Android Binaries Placed in jniLibs${NC}"


# --- PART B: iOS COMPILATION ---
echo -e "${BLUE}>>> Building for iOS...${NC}"

# Ensure targets exist (Fixes the "can't find crate for core" error)
echo "Ensuring Rust targets are installed..."
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# 1. Build for Device (ARM64)
echo "Compiling for iPhone Device (arm64)..."
cargo build --release --target aarch64-apple-ios || exit 1

# 2. Build for Simulator (ARM64)
echo "Compiling for Simulator (arm64)..."
cargo build --release --target aarch64-apple-ios-sim || exit 1

# 3. Build for Simulator (x86_64 - Intel)
echo "Compiling for Simulator (x86_64)..."
cargo build --release --target x86_64-apple-ios || exit 1

# 4. Create Universal Library using Lipo
echo "Stitching Universal Library..."
mkdir -p target/universal/release

# Combine x86 and arm64-sim into one "Fat" library for Simulators
lipo -create \
    target/x86_64-apple-ios/release/librust_core.a \
    target/aarch64-apple-ios-sim/release/librust_core.a \
    -output target/universal/release/librust_core.a || exit 1

# 5. Deployment
echo "Deploying Universal Simulator Library..."
cp "target/universal/release/librust_core.a" "$IOS_FLUTTER_DIR/librust_core.a"

echo -e "${GREEN}✓ Universal iOS Library Placed in ios/Runner${NC}"

cd "$ROOT_DIR"
echo -e "${BLUE}=== FACTORY SHUTDOWN. BUILD COMPLETE. ===${NC}"
