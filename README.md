# 🔐 SatyaSetu - Sovereign Spatial Marketplace

<div align="center">

**A privacy-first, decentralized spatial marketplace that transforms your camera into a Trust Sensor for discovering, verifying, and transacting with physical objects and vendors in your environment.**

![Version](https://img.shields.io/badge/version-1.15.0-blue)
![Phase](https://img.shields.io/badge/phase-Phase%2015-green)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20macOS-lightgrey)
![License](https://img.shields.io/badge/license-Private-red)

</div>

---

## 🔄 Before & After: Phase 11-15 Transformation

### What Changed on February 3, 2026

| Aspect | Before (Phase 1-10) | After (Phase 11-15) |
|--------|---------------------|---------------------|
| **Local Data** | Memory-only (ephemeral) | SQLite Trust Graph (persistent) |
| **Object Status** | No trust indicator | Trust score 0-100% with color coding |
| **Commerce** | None | Full marketplace with Reactive Drawer |
| **Verification** | Local only | Nostr broadcast to decentralized relays |
| **Backend** | None | PostgreSQL + Redis + FastAPI |
| **Network** | Image upload (full size) | Compressed (640px, 75% JPEG) |
| **UI on Tap** | Simple modal | Sovereign Drawer (Peek 40% / Market 90%) |
| **Ad Ranking** | N/A | Sovereign Ad Logic algorithm |

### Architecture Evolution

**Before (AR Viewer):**
```
Camera → AI Vision → Detection Boxes → Simple Modal
```

**After (Spatial Marketplace):**
```
Camera → AI Vision → Trust Graph Enrichment → Trust-Colored Overlays
    ↓
Tap Object → Sovereign Drawer (Peek/Market)
    ↓
Verified Tab ↔ Global Tab ↔ Bounties Tab
    ↓
Verify/Report → Nostr Broadcast → Trust Score Update
```

### New Files Added

| File | Purpose |
|------|--------|
| `database_service.dart` | SQLite Trust Graph (entities, interactions, cache) |
| `event_bus.dart` | Decoupled pub/sub communication |
| `commerce_service.dart` | Marketplace logic with Sovereign Ad Logic |
| `nostr_service.dart` | High-level Nostr event signing/broadcast |
| `sovereign_drawer.dart` | Reactive Drawer commerce UI |
| `docker-compose.yml` | PostgreSQL + Redis + FastAPI infrastructure |
| `backend/db/init.sql` | Database schema with ranking functions |
| `backend/search_api/main.py` | FastAPI search microservice |

---

## 📖 Table of Contents

- [Vision & Concept](#-vision--concept)
- [System Architecture](#-system-architecture)
- [Core Features](#-core-features)
- [Technology Stack](#-technology-stack)
- [Project Structure](#-project-structure)
- [Setup & Installation](#-setup--installation)
- [Build Instructions](#-build-instructions)
- [Technical Deep Dive](#-technical-deep-dive)
- [Security Model](#-security-model)
- [Development Workflow](#-development-workflow)
- [Troubleshooting](#-troubleshooting)
- [Roadmap](#-roadmap)

---

## 🎯 Vision & Concept

### The Problem

In today's digital landscape:
- **Identity is fragmented** across countless platforms and services
- **Privacy is compromised** through centralized data silos
- **Trust is broken** by intermediaries controlling our digital interactions
- **Proof of intent** is lost in opaque transaction systems

### The SatyaSetu Solution

**SatyaSetu** (Sanskrit: सत्य सेतु - "Bridge of Truth") is a **privacy-first, decentralized identity bridge** that empowers users to:

1. **Generate cryptographic identities** derived from hardware entropy
2. **Scan and understand** real-world interactions using on-device AI vision
3. **Sign interaction proofs** with Ed25519 digital signatures
4. **Broadcast to decentralized networks** via Nostr protocol
5. **Maintain complete sovereignty** over their identity and data

### Core Philosophy

> "Your identity, your keys, your proof - all on your device, forever."

SatyaSetu operates on three fundamental principles:

- **🔒 Privacy by Design**: All cryptographic operations happen locally. Keys never leave the device.
- **🌐 Decentralization First**: No central servers, no single point of failure. Nostr relays ensure global distribution.
- **🤖 Intelligence on the Edge**: On-device AI vision eliminates cloud dependencies for real-time scene understanding.

---

## 🏗️ System Architecture

SatyaSetu is built on a **hybrid Flutter-Rust architecture** with five distinct layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│              (Flutter - Dart Multi-Platform UI)              │
│  • Identity Lens (AI Vision with Trust-Colored Reticles)     │
│  • Sovereign Drawer (Reactive Commerce Interface)            │
│  • Proof Ledger (Interaction History)                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   APPLICATION LAYER                          │
│         (Dart Services + FFI Bridge to Rust Core)            │
│  • VisionService: On-device AI scene analysis (v111.0)       │
│  • DatabaseService: SQLite Trust Graph persistence           │
│  • CommerceService: Marketplace logic + Sovereign Ad Logic   │
│  • EventBus: Decoupled pub/sub communication                 │
│  • NostrService: Decentralized verification broadcast        │
│  • IntentEngine: Dual-tier interaction paradigm              │
│  • MissionControl: System telemetry & observability          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     CORE LAYER (Rust)                        │
│  • Cryptography: Ed25519, Argon2, ChaCha20-Poly1305          │
│  • Nostr SDK: Event signing, broadcasting, subscription      │
│  • Parsers: UPI QR code semantic extraction                  │
│  • Spatial: S2/Geohash indexing                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  INFRASTRUCTURE LAYER                        │
│  • Apple Vision Server: Local Python inference server        │
│  • Florence-2 VLM: Dense region captioning                   │
│  • Nostr Relays: wss://relay.damus.io, relay.nostr.band     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   BACKEND LAYER (Phase 14)                   │
│  • PostgreSQL: Vendors, products, ads, verifications         │
│  • PostGIS: Spatial queries for location-based search        │
│  • pgvector: Semantic search with embeddings                 │
│  • Redis: Caching and pub/sub                                │
│  • FastAPI: Search API with Sovereign Ad Logic               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow Architecture

```
Camera Capture → Sequential Heartbeat (300ms interval) → Apple Vision Server
    ↓
Florence-2 Dense Captioning → Detection Candidates → Vibrant Reticle Rendering
    ↓
User Taps Object → Vision Pause Control → Intent Engine Activation
    ↓
Tier 1: Florence Heuristic (0ms) → 2 Instant Choices
    ↓
Tier 2: Gemma LLM Async (~12s) → 3 Deep Inquiries
    ↓
User Selects Interaction → Intent Harvester → Ed25519 Signing
    ↓
Nostr Event Broadcasting → Local SQLite Ledger → Mission Control Telemetry
    ↓
Vision Resume → Reactive Heartbeat Continues
```

---

## ✨ Core Features

### 1. **Trust Graph** - Local Persistence (Phase 11)

- **SQLite Cortex**: Persistent local database for offline-first operation
- **Entity Memory**: Remembers detected objects with geohash and trust scores
- **Interaction Ledger**: Records VERIFY, RATE, BUY, REPORT actions
- **Product Cache**: Offline marketplace results with TTL expiration
- **Trust Score Evolution**: 0.0-1.0 score based on community verifications

**Trust Score Logic:**
```
VERIFY → +0.1 trust
RATE (5★) → +0.15 trust
RATE (1★) → -0.15 trust
REPORT → -0.2 trust
```

### 2. **Sovereign Drawer** - Commerce UI (Phase 12)

- **Reactive Drawer**: DraggableScrollableSheet with snap points (40%/90%)
- **Peek State (40%)**: Object title, trust badge, quick Verify/Report actions
- **Market State (90%)**: Tabbed ListView (Verified, Global, Bounties)
- **Trust-Colored UI**: Green (trusted), Gold (promoted), Red (untrusted), Blue (bounty)
- **EventBus Architecture**: Decoupled pub/sub for vision ↔ commerce communication

**Sovereign Ad Logic:**
```
Score = (Bid × AdvertiserTrust) + (OrganicRelevance × SocialProximity)
```

### 3. **Nostr Protocol** - Decentralized Verification (Phase 13)

- **Event Signing**: Rust FFI for cryptographic Nostr event creation
- **Relay Broadcasting**: Multi-relay distribution (Damus, Nostr.band)
- **Subscription Queries**: Fetch reviews/verifications by entity or author
- **DID Tagging**: Events tagged with `did:satya:` identifiers

**Event Kinds:**
| Kind | Purpose |
|------|--------|
| 1040 | Vendor Ads |
| 1985 | User Reviews/Verifications |
| 29001 | Signed Intents |
| 29002 | Trust Updates |

### 4. **Backend Microservices** (Phase 14)

- **PostgreSQL + PostGIS**: Spatial queries for location-based search
- **pgvector Extension**: Semantic search with 384-dim embeddings
- **Redis Caching**: 1-hour TTL for search results
- **FastAPI Search API**: `/v1/search`, `/v1/bounties`, `/v1/verification`
- **Docker Compose**: One-command infrastructure deployment

### 5. **Identity Lens** - Real-Time AI Vision

- **On-Device Florence-2 Vision Model**: Microsoft's vision-language model
- **Trust-Colored Reticles**: Objects colored by trust score (green/gray/red)
- **Image Compression**: 640px max width, 75% JPEG quality (Phase 15)
- **Dense Region Captioning**: Multi-object detection with bounding boxes
- **Zero Cloud Dependency**: All inference happens on-device

### 6. **Hierarchical Deterministic Identity System**

- **Hardware-Bound Entropy**: Device-specific identifiers seed the root key
- **PIN-Protected Vault**: User PIN + Hardware ID → Argon2 KDF → ChaCha20 encryption
- **Multi-Identity Support**: BIP32-like hierarchical derivation
- **Ed25519 Signatures**: Quantum-resistant signing

### 7. **QR Code Transaction Proof System**

- **UPI Intent Parsing**: Regex extraction of payment metadata
- **Cryptographic Signing**: Ed25519 signature over transaction data
- **Nostr Broadcasting**: Signed proofs published to decentralized relays

---

## 🛠️ Technology Stack

### Frontend (Flutter/Dart)

| Library | Version | Purpose |
|---------|---------|---------|
| `flutter_rust_bridge` | 1.82.6 | FFI bridge for Dart ↔ Rust communication |
| `mobile_scanner` | 7.1.4 | Hardware QR/barcode scanning (Apple Vision API, MLKit) |
| `camera_macos` | 0.0.9 | macOS camera access for AI vision pipeline |
| `google_fonts` | 5.0.0 | Custom typography (Inter, Roboto) |
| `lucide_icons` | 0.257.0 | Modern iconography |
| `http` | 1.2.0 | HTTP client for vision server communication |
| `image` | 4.2.0 | Hardware-accelerated image resizing |
| `path_provider` | 2.1.2 | Platform-specific storage paths |
| `device_info_plus` | 10.1.0 | Hardware ID extraction |

### Backend (Rust Core)

| Crate | Version | Purpose |
|-------|---------|---------|
| `ed25519-dalek` | 1.0.1 | Ed25519 digital signatures |
| `argon2` | 0.5 | Password-based key derivation (KDF) |
| `chacha20poly1305` | 0.10 | Authenticated encryption (AEAD) |
| `nostr-sdk` | 0.26 | Nostr protocol client (signing, broadcasting) |
| `serde/serde_json` | 1.0 | Serialization/deserialization |
| `ring` | 0.17 | Cryptographic primitives |
| `tokio` | 1.28 | Async runtime for Nostr networking |
| `uuid` | 1.4 | Unique identifier generation |
| `regex` | 1.9 | UPI QR code parsing |
| `bincode` | 1.3 | Binary encoding for performance |

### AI Vision (Python Server)

| Library | Purpose |
|---------|---------|
| `transformers` | Hugging Face model loading (Florence-2) |
| `torch` | PyTorch inference engine |
| `fastapi` | HTTP API server |
| `uvicorn` | ASGI server |
| `Pillow` | Image processing |

**Model Details:**
- **Florence-2-base**: 232M parameter vision-language model
- **Task**: `<DENSE_REGION_CAPTION>` (object detection + labeling)
- **Backend**: Apple MPS (Metal Performance Shaders)
- **Optimization**: Greedy decoding (`num_beams=1`), 128 token limit

---

## 📂 Project Structure

```
SatyaSetu_Internal/
│
├── flutter_app/                    # Flutter mobile/desktop application
│   ├── lib/
│   │   ├── main.dart              # Main app entry + UI (v112.0.0)
│   │   ├── identity_domain.dart   # Core domain models
│   │   ├── identity_repo.dart     # Abstract repository interface (v1.13.0)
│   │   ├── identity_repo_native.dart # Native Rust FFI implementation
│   │   ├── bridge_generated.dart  # Auto-generated FFI bindings
│   │   ├── services/
│   │   │   ├── vision_service.dart           # AI vision orchestration (v111.0)
│   │   │   ├── database_service.dart         # SQLite Trust Graph (NEW)
│   │   │   ├── event_bus.dart                # Pub/sub communication (NEW)
│   │   │   ├── commerce_service.dart         # Marketplace logic (NEW)
│   │   │   ├── nostr_service.dart            # Nostr event handling (NEW)
│   │   │   ├── intent_engine.dart            # Dual-tier interaction paradigm
│   │   │   ├── mission_control_service.dart  # System telemetry
│   │   │   ├── intent_harvester.dart         # Cryptographic ledger
│   │   │   ├── vault_service.dart            # Encrypted storage
│   │   │   └── hardware_id_service.dart      # Device fingerprinting
│   │   ├── widgets/
│   │   │   └── sovereign_drawer.dart         # Reactive Drawer UI (NEW)
│   │   └── models/
│   │       ├── intent_models.dart            # MorphicAction, SituationState
│   │       └── telemetry_models.dart         # SystemPulse, SystemHealth
│   ├── ios/                       # iOS-specific configuration
│   ├── android/                   # Android-specific configuration
│   ├── macos/                     # macOS-specific configuration
│   └── pubspec.yaml               # Flutter dependencies (v1.15.0)
│
├── rust_core/                     # Rust cryptographic core
│   ├── src/
│   │   ├── lib.rs                 # Library entry point
│   │   ├── api.rs                 # Public FFI API (Phase 13 additions)
│   │   ├── crypto.rs              # Ed25519, Argon2, ChaCha20
│   │   ├── domain.rs              # Core domain types
│   │   ├── persistence.rs         # SQLite vault management
│   │   ├── parser.rs              # UPI QR parsing logic
│   │   ├── spatial.rs             # S2/Geohash indexing
│   │   └── bridge_generated.rs    # Auto-generated FFI bridge
│   └── Cargo.toml                 # Rust dependencies
│
├── backend/                       # Backend Microservices (NEW)
│   ├── db/
│   │   └── init.sql               # PostgreSQL schema
│   └── search_api/
│       ├── main.py                # FastAPI search service
│       ├── Dockerfile             # Container configuration
│       └── requirements.txt       # Python dependencies
│
├── docker-compose.yml             # Infrastructure orchestration (NEW)
├── apple_vision_server.py         # Local AI vision inference server
├── build_mobile.sh                # Cross-platform build orchestrator
├── WALKTHROUGH_Phases_11-15.md    # Implementation documentation (NEW)
└── README.md                      # This file
```

### Key Configuration Files

#### `pubspec.yaml` - Flutter Dependencies
- Defines all Dart/Flutter package dependencies
- Configures SDK constraints (`>=3.0.0 <4.0.0`)
- Specifies asset bundles and fonts

#### `Cargo.toml` - Rust Dependencies
- Defines Rust crate dependencies
- Configures static library (`staticlib`) and dynamic library (`cdylib`) outputs
- Sets compilation profile (release/debug)

#### `build_mobile.sh` - Build Orchestrator
- Regenerates Flutter-Rust bridge code (`flutter_rust_bridge_codegen`)
- Compiles Rust for Android (arm64-v8a, armeabi-v7a, x86_64) via `cargo-ndk`
- Compiles Rust for iOS (aarch64-apple-ios-sim, universal binary)
- Compiles Rust for macOS (aarch64-apple-darwin, dynamic library)

---

## 🚀 Setup & Installation

### Prerequisites

#### System Requirements
- **macOS** 12.0+ (for iOS/macOS builds) with Apple Silicon or Intel
- **Xcode** 14.0+ with Command Line Tools
- **Android Studio** (for Android builds) with NDK 28.2.13676358

#### Required Tools
```bash
# Flutter SDK (>= 3.0.0)
flutter --version

# Rust toolchain
rustup --version
cargo --version

# Python 3.10+ (for vision server)
python3 --version
pip3 --version

# CocoaPods (iOS)
pod --version

# Android NDK (for Android)
# Ensure NDK 28.2.13676358 is installed via Android Studio SDK Manager
```

### Step 1: Install Rust Targets

```bash
# iOS targets
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# Android targets
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android

# macOS target
rustup target add aarch64-apple-darwin

# Install cargo-ndk for Android compilation
cargo install cargo-ndk
```

### Step 2: Clone and Setup Flutter

```bash
cd ~/Development/SatyaSetu_Internal

# Install Flutter dependencies
cd flutter_app
flutter pub get
cd ..

# iOS: Install CocoaPods dependencies
cd flutter_app/ios
pod install
cd ../..
```

### Step 3: Setup Vision Server (macOS only)

```bash
# Install Python dependencies
pip3 install torch torchvision torchaudio
pip3 install transformers
pip3 install fastapi uvicorn pillow

# Download Florence-2 model (auto-downloads on first run)
# Model will be cached in ~/.cache/huggingface/
```

**Note:** The actual model weights in `apple_vlm_weights/` are gitignored. The server will auto-download them from Hugging Face on first run.

### Step 4: Configure Build Paths (Android only)

Edit `build_mobile.sh` if your Android SDK is not at `/Volumes/Apple/Android/sdk`:

```bash
# Line 14
ANDROID_SDK_ROOT="/path/to/your/android/sdk"
```

---

## 🔨 Build Instructions

### Build All Platforms

The master build script compiles Rust core for all targets and deploys binaries:

```bash
./build_mobile.sh
```

**This script will:**
1. ✅ Regenerate Flutter-Rust FFI bridge code
2. ✅ Compile Rust for Android (arm64-v8a) → `flutter_app/android/app/src/main/jniLibs/`
3. ✅ Compile Rust for iOS (universal binary) → `flutter_app/ios/Runner/librust_core.a`
4. ✅ Compile Rust for macOS (dylib) → `flutter_app/macos/librust_core.dylib`
5. ✅ Copy binaries to Flutter app bundle

**Expected Output:**
```
>>> [1/3] FFI Sync (Codegen)...
Building Android Binaries...
Building iOS Static Libs...
Building macOS Native (.dylib)...
✓ Phase 6.8 Trinity Build Successful.
```

### Run Flutter App

#### macOS Desktop (with AI Vision)

```bash
# Terminal 1: Start vision server
python3 apple_vision_server.py

# Terminal 2: Run Flutter app
cd flutter_app
flutter run -d macos
```

**Expected Vision Server Output:**
```
============================================================
   SATYA COGNITIVE BRIDGE v8.4.0
   Intelligence: Florence-2 (Atomic Cool-Down)
============================================================
[ENGINE] Mounting Neural Core: microsoft/Florence-2-base...
SUCCESS: Dense Perception active on MPS.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

#### iOS Simulator

```bash
cd flutter_app
flutter run -d "iPhone 15 Pro"
```

#### iOS Physical Device

```bash
cd flutter_app
flutter build ios --release
# Open Xcode to deploy to device
open ios/Runner.xcworkspace
```

#### Android Emulator/Device

```bash
cd flutter_app
flutter run
```

### Build Release APK (Android)

```bash
cd flutter_app
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔬 Technical Deep Dive

### 1. Reactive Heartbeat Architecture (Phase 69)

#### Problem Statement

Early versions used Timer-based polling for vision inference, which caused memory ballooning and request flooding when the LLM backend was busy. Multiple in-flight requests would queue up, leading to OOM crashes on resource-constrained devices.

#### Solution: Sequential Request-Response Cycle

```dart
// vision_service.dart (v83.0)
Future<void> _runDecoupledHeartbeat() async {
  while (_isRunning) {
    if (macController != null && !isPaused) {
      await _performPulse();  // Wait for completion
    }
    await Future.delayed(const Duration(milliseconds: 350));
  }
}
```

**Key Innovations:**
1. **Sequential Execution**: Only one inference request in-flight at a time
2. **Pause Control**: `isPaused` flag stops vision during heavy Gemma reasoning
3. **Adaptive Polling**: 300-350ms interval balances responsiveness with thermal management
4. **Memory-Bounded**: No request queues or latency buffers

#### Pause Control Mechanism

```dart
// main.dart - User taps object
void _showIntentCard(DetectionCandidate candidate) {
  widget.visionService.isPaused = true;  // Stop camera
  
  showModalBottomSheet(...)
    .whenComplete(() {
      widget.visionService.isPaused = false;  // Resume camera
    });
}
```

**Benefits:**
- Prevents camera floods during modal interactions
- Reduces GPU contention between Florence-2 and Gemma
- Improves UX by avoiding UI jank during reasoning

#### Python Server GPU Memory Locking

```python
# apple_vision_server.py
FLORENCE_LOCK = asyncio.Lock()
GEMMA_LOCK = asyncio.Lock()

async with FLORENCE_LOCK:
    outputs = processor.post_process_generation(
        generated_ids, task_prompt=task, image_size=(w, h)
    )
    torch.mps.empty_cache()  # Explicit cleanup
```

**Synchronization:**
- Prevents concurrent Florence-2 + Gemma inference
- Eliminates MPS backend race conditions
- Enforces FP16 precision for consistent memory usage

### 2. AI Vision Pipeline (Phase 10-69)

#### Architecture

```
Camera Frame Capture (CameraMacOS)
    ↓
Hardware Resize to 768px (dart:ui.Image codec)
    ↓
PNG Encoding + Base64
    ↓
HTTP POST to localhost:8000/v1/vision
    ↓
Python FastAPI Server
    ↓
Florence-2 Inference (MPS backend)
    ↓
Dense Region Caption: <bboxes + labels>
    ↓
JSON Response [{"label": "...", "box_2d": [...]}]
    ↓
Dart Semantic Parsing (Living vs Object classification)
    ↓
Animated Reticle Rendering (Red = Living, Cyan = Object)
```

#### Key Optimizations

**Problem:** Ollama moondream on M1 had 40s+ latency and frequent thermal throttling.

**Solution (Phase 10):**
1. **Migrated to Florence-2**: 10x faster inference (2-3s vs 40s)
2. **Hardware Resize**: Dart-side resize to 768px before transmission
3. **Thermal Throttling Detection**: 10s timeout kills hung requests
4. **Frame Rate Limiting**: 2.5s capture interval for M1 thermal recovery
5. **GPU Memory Management**: Explicit `torch.mps.empty_cache()` after each inference

**Code Reference:** `flutter_app/lib/services/vision_service.dart`, `apple_vision_server.py`

#### Living vs Object Classification

```dart
final livingKeywords = ["MAN", "WOMAN", "BOY", "GIRL", "CHILD", "SISTER", "SON", "PERSON", "FACE", "HEAD"];
final interactionKeywords = ["HOLDING", "WEARING", "CARRYING", "USING", "TOUCHING", "HAND"];

bool mentionsLiving = livingKeywords.any((w) => label.contains(w));
bool mentionsInteraction = interactionKeywords.any((w) => label.contains(w));
bool isLiving = mentionsLiving && !mentionsInteraction;
```

**Semantic Color Logic:**
- **Red Reticles** (`0xFFFF4545`): Living beings (person, face, etc.)
- **Cyan Reticles** (`0xFF00FFC8`): Objects or living beings holding objects

### 3. Dual-Tier Interaction System (Phase 52+)

#### Architecture

The Intent Engine implements a "2+3" choice separation paradigm that balances instant user trust with deep contextual reasoning:

**Tier 1: Florence Heuristic (0ms latency)**
```dart
// intent_engine.dart
static SituationState resolveInstant(String label) {
  final Color color = generateVibrantColor(label);
  
  List<MorphicAction> instantActions = [
    MorphicAction(
      label: "Visual Ground Truth", 
      icon: LucideIcons.eye, 
      description: "Verified presence of $label"
    ),
    MorphicAction(
      label: "Market Snapshot", 
      icon: LucideIcons.indianRupee, 
      description: "Fetch local index for $label"
    ),
  ];
  return SituationState(title: "Perception Tier", actions: instantActions, themeColor: color);
}
```

**Tier 2: Gemma LLM Async (~12s)**
```dart
static Future<List<String>> fetchInquiries(String label) async {
  final response = await http.post(
    Uri.parse("http://127.0.0.1:8000/v1/reason"),
    body: jsonEncode({"object": label})
  ).timeout(const Duration(seconds: 15));
  
  return List<String>.from(jsonDecode(response.body)['questions']);
}
```

#### Spectral Color Generation

```dart
static Color generateVibrantColor(String text) {
  return HSVColor.fromAHSV(
    1.0,                                  // Alpha (fully opaque)
    (text.hashCode % 360).toDouble(),     // Hue (deterministic from label)
    0.8,                                  // Saturation (vibrant)
    0.95                                  // Value (bright)
  ).toColor();
}
```

**Color Examples:**
- "LAPTOP" → HSV(120°, 80%, 95%) = Vibrant Green
- "PHONE" → HSV(240°, 80%, 95%) = Electric Blue  
- "PERSON" → HSV(330°, 80%, 95%) = Hot Pink

#### UI Flow

```
1. User taps vibrant reticle
     ↓
2. Vision pauses (isPaused = true)
     ↓
3. Modal opens with Tier 1 choices (instant)
     ↓
4. Gemma async reasoning starts (background)
     ↓
5. Tier 2 choices populate when ready (~12s)
     ↓
6. User selects any choice (Tier 1 or Tier 2)
     ↓
7. Intent Harvester records interaction
     ↓
8. Modal closes, vision resumes (isPaused = false)
```

### 4. Cryptographic Identity System

#### Vault Initialization

```rust
// rust_core/src/crypto.rs (simplified)
pub fn initialize_vault(pin: &str, hardware_id: &str) -> Result<MasterSeed> {
    let salt = format!("{}{}", hardware_id, GLOBAL_SALT);
    let config = argon2::Config::default();
    
    // Argon2id KDF: pin + hardware_id → 256-bit master seed
    let hash = argon2::hash_raw(pin.as_bytes(), salt.as_bytes(), &config)?;
    Ok(MasterSeed(hash))
}
```

### 5. Identity Derivation

```rust
pub fn derive_identity(master_seed: &MasterSeed, index: u32) -> Ed25519KeyPair {
    let derivation_path = format!("m/44'/0'/0'/{}", index);
    let secret = hmac_sha512(&master_seed.0, derivation_path.as_bytes());
    
    let signing_key = SigningKey::from_bytes(&secret[..32]);
    let verifying_key = signing_key.verifying_key();
    
    Ed25519KeyPair { signing_key, verifying_key }
}
```

#### Decentralized Identifier (DID)

```rust
pub fn generate_did(public_key: &VerifyingKey) -> String {
    format!("did:satya:{}", hex::encode(public_key.as_bytes()))
}
```

**Example DID:** `did:satya:03a2f8b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2`

### 6. UPI QR Code Parsing

```rust
// rust_core/src/parser.rs
pub fn parse_upi_qr(raw: &str) -> Result<UpiIntent> {
    let re = Regex::new(r"upi://pay\?pa=([^&]+)&pn=([^&]+)&am=([^&]+)&cu=([^&]+)")?;
    
    if let Some(caps) = re.captures(raw) {
        Ok(UpiIntent {
            vpa: caps[1].to_string(),      // Virtual Payment Address
            name: caps[2].to_string(),      // Merchant name
            amount: caps[3].to_string(),    // Transaction amount
            currency: caps[4].to_string(),  // Currency code (INR)
        })
    } else {
        Err(anyhow!("Invalid UPI QR format"))
    }
}
```

**UPI QR Format:**
```
upi://pay?pa=merchant@bank&pn=MerchantName&am=500&cu=INR
```

### 7. Nostr Event Broadcasting

```rust
// rust_core/src/service.rs (simplified)
pub async fn publish_to_nostr(signed_intent: &str) -> Result<bool> {
    let client = Client::new(&keys);
    
    // Add relays
    client.add_relay("wss://relay.damus.io", None).await?;
    client.add_relay("wss://relay.nostr.band", None).await?;
    
    client.connect().await;
    
    // Create Kind-1 text event with signed intent
    let event = EventBuilder::new(Kind::TextNote, signed_intent, &[])
        .to_event(&keys)?;
    
    // Broadcast to all relays
    client.send_event(event).await?;
    Ok(true)
}
```

**Nostr Event Structure:**
```json
{
  "id": "7f3a19c2...",
  "pubkey": "03a2f8b4...",
  "created_at": 1735679352,
  "kind": 1,
  "tags": [],
  "content": "{\"identity\":\"did:satya:...\", \"intent\":{...}, \"signature\":\"...\"}",
  "sig": "A89BC3F2D..."
}
```

---

## 🔐 Security Model

### Threat Model

SatyaSetu is designed to resist the following attacks:

1. **Device Theft**: PIN + Hardware ID dual-factor protection
2. **Malware Key Exfiltration**: Keys never leave Rust secure enclave
3. **Network Eavesdropping**: All sensitive operations are local; Nostr events are public by design
4. **Replay Attacks**: Nonce + timestamp in every signed proof
5. **Relay Censorship**: Multi-relay redundancy ensures availability

### Security Properties

| Property | Mechanism | Status |
|----------|-----------|--------|
| **Confidentiality** | ChaCha20-Poly1305 AEAD encryption for vault | ✅ Implemented |
| **Integrity** | Ed25519 signatures on all proofs | ✅ Implemented |
| **Authenticity** | DID-based public key verification | ✅ Implemented |
| **Non-Repudiation** | Immutable Nostr event log | ✅ Implemented |
| **Forward Secrecy** | HD derivation supports key rotation | 🚧 Partial |
| **Privacy** | On-device AI, no telemetry | ✅ Implemented |

### Cryptographic Primitives

- **Ed25519**: 128-bit security level, quantum-resistant (conjectured)
- **Argon2id**: Memory-hard KDF resistant to GPU/ASIC attacks
- **ChaCha20-Poly1305**: IETF ChaCha20 with Poly1305 MAC (AEAD)
- **HMAC-SHA512**: Key derivation function for HD identities

**Key Sizes:**
- Master Seed: 256 bits
- Ed25519 Private Key: 256 bits
- Ed25519 Public Key: 256 bits
- Nonce: 192 bits (ChaCha20-Poly1305)

---

## 💻 Development Workflow

### 1. Making Rust Changes

```bash
# Edit Rust source
vim rust_core/src/crypto.rs

# If API surface changes, regenerate FFI bridge
flutter_rust_bridge_codegen \
    --rust-input rust_core/src/api.rs \
    --dart-output flutter_app/lib/bridge_generated.dart \
    --rust-output rust_core/src/bridge_generated.rs

# Rebuild Rust for all platforms
./build_mobile.sh
```

### 2. Making Flutter UI Changes

```bash
# Edit UI
vim flutter_app/lib/main.dart

# Hot reload (if app is already running)
# Press 'r' in terminal or use IDE hot reload

# Full restart
flutter run
```

### 3. Updating Vision Model

```bash
# Edit vision server
vim apple_vision_server.py

# Restart server
python3 apple_vision_server.py

# Test from Flutter
cd flutter_app && flutter run -d macos
```

### 4. Testing Workflow

```bash
# Run Dart tests
cd flutter_app
flutter test

# Run Rust tests
cd rust_core
cargo test

# Integration test on device
flutter run --release -d <device-id>
```

---

## 🐛 Troubleshooting

### iOS Build Issues

#### Error: "Framework 'Pods_Runner' not found"

**Solution:**
```bash
cd flutter_app/ios
pod deintegrate
pod install
cd ../..
flutter clean
flutter run
```

#### Error: "librust_core.a not found"

**Solution:**
```bash
./build_mobile.sh  # Rebuild Rust binaries
flutter clean
flutter run
```

#### Error: "Apple Silicon simulator architecture mismatch"

**Solution:** Ensure `Podfile` has ARM64 simulator configuration:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      config.build_settings['ARCHS'] = 'arm64'
    end
  end
end
```

### Android Build Issues

#### Error: "NDK not found"

**Solution:**
```bash
# Install NDK via Android Studio SDK Manager
# Or update path in build_mobile.sh:
ANDROID_SDK_ROOT="/path/to/your/sdk"
```

#### Error: "librust_core.so not found"

**Solution:**
```bash
./build_mobile.sh  # Rebuild Android binaries
flutter clean
flutter run
```

### Vision Server Issues

#### Error: "Connection refused on port 8000"

**Solution:**
```bash
# Ensure server is running
python3 apple_vision_server.py

# Check if port is in use
lsof -i :8000
```

#### Error: "MPS backend not available"

**Solution:**
```bash
# Verify PyTorch MPS support
python3 -c "import torch; print(torch.backends.mps.is_available())"

# If False, reinstall PyTorch with MPS support:
pip3 install --upgrade torch torchvision torchaudio
```

#### Error: "Model download fails"

**Solution:**
```bash
# Manually download Florence-2-base
python3 -c "
from transformers import AutoModelForCausalLM
AutoModelForCausalLM.from_pretrained('microsoft/Florence-2-base', trust_remote_code=True)
"
```

### Rust Compilation Issues

#### Error: "can't find crate for core"

**Solution:**
```bash
# Ensure all targets are installed
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
rustup target add aarch64-linux-android
rustup target add aarch64-apple-darwin

# Update rustup
rustup update
```

---

## 🗺️ Roadmap

### ✅ Completed (Phase 1-15)
- [x] Hierarchical deterministic identity system with Ed25519
- [x] On-device Florence-2 vision with semantic object detection
- [x] Reactive heartbeat architecture with pause control
- [x] Dual-tier interaction paradigm (Florence + Gemma)
- [x] Mission Control telemetry and observability
- [x] Intent Harvester cryptographic ledger
- [x] **Phase 11: SQLite Trust Graph (entities, interactions, cache)**
- [x] **Phase 12: Sovereign Drawer commerce UI with EventBus**
- [x] **Phase 13: Nostr event signing/broadcasting via Rust FFI**
- [x] **Phase 14: PostgreSQL + Redis + FastAPI backend**
- [x] **Phase 15: Image compression optimization**

### Phase 16-20 (Q1 2026) - Production Hardening
- [ ] GST verification API integration
- [ ] UPI payment gateway integration
- [ ] Production Nostr relay deployment
- [ ] Trust graph aggregation algorithms
- [ ] Vendor onboarding portal

### Phase 21-25 (Q2 2026) - Scale & Federation
- [ ] Multi-relay trust consensus
- [ ] Regional geofencing for marketplace
- [ ] Federated search across relay networks
- [ ] Advanced fraud detection ML

### Phase 26-30 (Q3 2026) - Privacy Enhancements
- [ ] Zero-knowledge proofs for selective disclosure
- [ ] Encrypted computation for trust scores
- [ ] Onion routing for relay anonymity
- [ ] Quantum-resistant signature migration

---

## 📊 Performance Benchmarks (M1 MacBook Air, 8GB RAM)

| Operation | Time | Notes |
|-----------|------|-------|
| **Vault Initialization** | ~500ms | Argon2 KDF dominates |
| **Identity Derivation** | ~2ms | HMAC-SHA512 + Ed25519 keygen |
| **Ed25519 Signature** | ~0.5ms | Per transaction proof |
| **UPI QR Parsing** | ~0.1ms | Regex extraction |
| **Nostr Event Broadcast** | ~200ms | Network-dependent |
| **Vision Inference (Florence-2)** | ~1.5-2s | Optimized with FP16 + MPS cache clearing |
| **Gemma Reasoning (3 inquiries)** | ~12s | Local LLM deep context generation |
| **Frame Capture + Resize** | ~100ms | Hardware-accelerated |
| **Intent Engine Tier 1** | <1ms | Instant heuristic generation |
| **Spectral Color Generation** | <0.1ms | HSV color space calculation |

**Memory Usage:**
- Flutter App: ~150MB (idle), ~300MB (camera active)
- Vision Server: ~3.5GB (Florence-2 + Gemma dual-model loading)
- Rust Core: ~5MB (static library)
- Intent Engine: ~10MB (in-memory state)
- Mission Control: ~5MB (telemetry streams)

---

## 🤝 Contributing

This is a private internal project. External contributions are not currently accepted.

For team members:
1. Create feature branch from `main`
2. Make changes with atomic commits
3. Test on iOS + Android + macOS
4. Submit PR with detailed description

---

## 📄 License

**Proprietary** - All Rights Reserved

This software is the exclusive property of the SatyaSetu project. Unauthorized copying, distribution, or modification is strictly prohibited.

---

## 👥 Credits

**Core Team:**
- Architecture & Cryptography
- AI Vision Integration
- Flutter UI/UX
- Rust Systems Programming

**Open Source Dependencies:**
- **Flutter Team** - Cross-platform framework
- **Rust Foundation** - Systems programming language
- **Microsoft Research** - Florence-2 vision model
- **Nostr Protocol** - Decentralized social infrastructure
- **Hugging Face** - Model hosting and transformers library

---

## 📞 Support

For internal support, contact the development team via:
- **GitHub Issues** (private repository)
- **Internal Slack** channel: `#satyasetu-dev`

---

**Built with ❤️ for a decentralized future.**

*Last Updated: February 3, 2026*  
*Version: 1.15.0 (Phase 15 - Sovereign Spatial Marketplace Complete)*
