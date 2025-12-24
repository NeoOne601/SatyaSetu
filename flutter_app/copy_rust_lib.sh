#!/bin/bash
# Auto-copy Rust library after build
# This script ensures librust_core.dylib is always in the app bundle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_LIB="$SCRIPT_DIR/macos/librust_core.dylib"
FRAMEWORKS_DIR="$SCRIPT_DIR/build/macos/Build/Products/Debug/flutter_app.app/Contents/Frameworks"

if [ -f "$RUST_LIB" ]; then
  mkdir -p "$FRAMEWORKS_DIR"
  cp "$RUST_LIB" "$FRAMEWORKS_DIR/"
  echo "✅ Copied librust_core.dylib to Frameworks"
else
  echo "⚠️  Warning: librust_core.dylib not found"
  exit 1
fi
