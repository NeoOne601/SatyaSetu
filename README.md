# SatyaSetu Internal

A cross-platform mobile application built with Flutter and Rust, combining the power of native performance with beautiful UI.

## 🏗️ Project Structure

```
SatyaSetu_Internal/
├── flutter_app/          # Flutter mobile application
├── rust_core/            # Rust core library for cryptography and data processing
├── build_mobile.sh       # Cross-compilation build script
├── migration_protocol.sh # Migration helper script
└── logs/                 # Build and runtime logs
```

## 🚀 Features

- **QR Code Scanning**: Built-in barcode/QR scanner using Apple Vision API (iOS) and MLKit (Android)
- **Cryptographic Operations**: Ed25519 digital signatures powered by Rust
- **SQLite Database**: Local data persistence with Rust-based SQLite integration
- **Cross-Platform**: Runs on both iOS and Android with shared Rust core logic
- **Custom UI**: Beautiful interface using Google Fonts and Lucide Icons

## 📋 Prerequisites

### Required Tools

- **Flutter SDK** (>= 3.0.0)
- **Rust** (latest stable)
  - `rustup` toolchain manager
  - Rust targets for mobile platforms
- **Xcode** 26.2+ (for iOS development on macOS)
- **Android Studio** / Android SDK (for Android development)
- **cargo-ndk** (for Android Rust compilation)

### Platform-Specific Requirements

#### iOS Development
- macOS with Apple Silicon or Intel
- Xcode Command Line Tools
- CocoaPods (`gem install cocoapods`)
- iOS Simulator or physical device

#### Android Development
- Android SDK at `/Volumes/Apple/Android/sdk` (or update path in `build_mobile.sh`)
- NDK version 28.2.13676358
- JDK 17 or higher

## 🛠️ Setup Instructions

### 1. Clone and Navigate

```bash
cd ~/Development/SatyaSetu_Internal
```

### 2. Install Rust Targets

```bash
# For iOS
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# For Android
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

# Install cargo-ndk for Android builds
cargo install cargo-ndk
```

### 3. Install Flutter Dependencies

```bash
cd flutter_app
flutter pub get
```

### 4. Install iOS Dependencies (macOS only)

```bash
cd flutter_app/ios
pod install
cd ../..
```

## 🔨 Building the Project

### Build Rust Core for All Platforms

The project includes a comprehensive build script that compiles the Rust core for both Android and iOS:

```bash
./build_mobile.sh
```

This script will:
1. Compile Rust for Android architectures (arm64-v8a, armeabi-v7a, x86_64)
2. Compile Rust for iOS (device and simulator, both ARM64 and x86_64)
3. Create a universal iOS library using `lipo`
4. Copy binaries to the appropriate Flutter directories

### Build Flutter App

#### iOS Simulator
```bash
cd flutter_app
flutter run
# or specify a device
flutter run -d <device-id>
```

#### iOS Device
```bash
flutter build ios --release
```

#### Android Emulator/Device
```bash
flutter run
# or
flutter build apk --release
```

## 🧩 Technology Stack

### Flutter (Dart)
- **flutter_rust_bridge**: FFI bridge to Rust native code
- **mobile_scanner**: QR/barcode scanning (v7.1.4 with Apple Vision API)
- **google_fonts**: Custom typography
- **lucide_icons**: Modern iconography
- **ffi**: Foreign Function Interface for Rust integration

### Rust Core
- **ed25519-dalek**: Digital signature cryptography
- **rusqlite**: SQLite database with bundled driver
- **serde/serde_json**: Serialization/deserialization
- **chrono**: Date and time handling
- **flutter_rust_bridge**: Dart-Rust bridge code generation

## 📱 iOS Build Configuration

The iOS build uses a custom configuration to support:
- **ARM64 architecture** for Apple Silicon simulators and devices
- **CocoaPods integration** with custom `.xcconfig` files
- **Rust static library** linking via `OTHER_LDFLAGS`

### Known iOS Configuration Details

The project includes specific fixes for Apple Silicon development:
- CocoaPods architecture overrides in `Podfile` post_install hook
- Custom `.xcconfig` files for Debug and Release builds
- Universal binary support for both Intel and ARM64 simulators

## 🗂️ Rust Core Architecture

The Rust core is organized into modular components:

```
rust_core/src/
├── lib.rs              # Library entry point
├── api.rs              # Public API exposed to Flutter
├── bridge_generated.rs # flutter_rust_bridge generated code
├── crypto.rs           # Cryptographic operations
├── domain.rs           # Domain models and types
├── parser.rs           # Data parsing utilities
├── persistence.rs      # SQLite database operations
└── service.rs          # Business logic services
```

## 🐛 Troubleshooting

### iOS Build Issues

**Error: "Framework 'Pods_Runner' not found"**
- Run `pod install` in `flutter_app/ios/`
- Clean Flutter: `flutter clean`
- Rebuild: `flutter run`

**Error: "Runner's architectures (Intel 64-bit) include none that iPhone can execute (arm64)"**
- Ensure the Podfile post_install hook has ARM64 configuration
- Rebuild Rust core: `./build_mobile.sh`
- Clean and rebuild Flutter

### Android Build Issues

**Error: "NDK not found"**
- Verify NDK path in `build_mobile.sh` matches your installation
- Check that NDK version 28.2.13676358 is installed
- Mount external drive if SDK is on `/Volumes/Apple`

### Rust Compilation Issues

**Error: "can't find crate for core"**
- Ensure all Rust targets are installed (see Setup Instructions)
- Update rustup: `rustup update`

## 📝 Development Workflow

1. **Make Rust changes** in `rust_core/src/`
2. **Regenerate bridge code** if API changes:
   ```bash
   flutter_rust_bridge_codegen generate
   ```
3. **Rebuild Rust core**:
   ```bash
   ./build_mobile.sh
   ```
4. **Run Flutter app**:
   ```bash
   cd flutter_app && flutter run
   ```

## 🔒 Security Considerations

- The Rust core handles cryptographic operations using industry-standard Ed25519
- All sensitive data should be stored securely using the SQLite persistence layer
- Private keys are never transmitted over the network

## 📄 License

Internal project - All rights reserved

## 👥 Contributors

Built with dedication by the SatyaSetu team.

---

**Last Updated**: December 2025  
**Project Status**: Active Development
