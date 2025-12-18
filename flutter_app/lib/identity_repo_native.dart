import 'identity_domain.dart';
import 'identity_repo.dart';
import 'bridge_generated.dart';
import 'dart:ffi';
import 'dart:io';

// ==============================================================================
// STRATEGY PATTERN: PLATFORM LOADING
// ==============================================================================
// We separate the "How to find the binary" logic from the "How to use it" logic.
// This allows us to handle the complex macOS external drive fallback cleanly.

abstract class RustLoaderStrategy {
  DynamicLibrary loadLibrary();
}

class AndroidLoader implements RustLoaderStrategy {
  @override
  DynamicLibrary loadLibrary() {
    // Android automatically looks in the APK's lib/ folder
    return DynamicLibrary.open('librust_core.so');
  }
}

class IOSLoader implements RustLoaderStrategy {
  @override
  DynamicLibrary loadLibrary() {
    // iOS links statically into the main executable runner
    return DynamicLibrary.process();
  }
}

class MacOSLoader implements RustLoaderStrategy {
  @override
  DynamicLibrary loadLibrary() {
    // STRATEGY: "Failover Loading"
    // 1. Try the Production Path (Inside the .app bundle Frameworks)
    // 2. If that fails (Sandbox/Dev issues), try the Antigravity Path (External Drive)

    try {
      final path =
          '${File(Platform.resolvedExecutable).parent.path}/../Frameworks/librust_core.dylib';
      return DynamicLibrary.open(path);
    } catch (e) {
      print(
          "⚠️ Bundle load failed. Attempting Antigravity Fallback (External Drive)...");
      // Note: This path is specific to your dev environment.
      // In production, this fallback would be removed or point to a safe default.
      return DynamicLibrary.open(
          '/Volumes/Apple/Development/SatyaSetu_Monorepo/rust_core/target/debug/librust_core.dylib');
    }
  }
}

// FACTORY: Chooses the correct strategy based on the OS
class RustLoaderFactory {
  static RustLoaderStrategy getStrategy() {
    if (Platform.isAndroid) return AndroidLoader();
    if (Platform.isIOS) return IOSLoader();
    if (Platform.isMacOS) return MacOSLoader();
    throw UnsupportedError('Platform not supported for Native Rust Loader');
  }
}

// ==============================================================================
// REPOSITORY IMPLEMENTATION
// ==============================================================================

class IdentityRepoNative implements IdentityRepository {
  // 1. SINGLETON HOLDER
  // Must be static to survive Widget rebuilds.
  // Holds the active connection to the Rust brain.
  static RustCoreImpl? _apiInstance;

  // 2. LAZY INITIALIZER / GETTER
  // Thread Safety: Dart is single-threaded. This synchronous check is atomic.
  RustCoreImpl get api {
    // A. If already connected, return the existing wire.
    if (_apiInstance != null) return _apiInstance!;

    print("NATIVE MODE: Initializing Rust Core...");

    // B. If not, Execute Loading Strategy
    final strategy = RustLoaderFactory.getStrategy();
    final dylib = strategy.loadLibrary();

    // C. Create the Bridge and cache it.
    _apiInstance = RustCoreImpl(dylib);
    return _apiInstance!;
  }

  @override
  Future<SatyaIdentity> createIdentity() async {
    try {
      // Access the singleton (initializes if null)
      final rustApi = api;

      print("Requesting Identity Generation...");

      // FFI Call: This crosses the boundary from Dart -> C -> Rust
      final jsonString = await rustApi.rustGenerateDidSafe();
      print("RUST RESPONSE: $jsonString");

      return SatyaIdentity(did: jsonString, pubKey: "secure_enclave_protected");
    } catch (e) {
      print("CRITICAL BRIDGE ERROR: $e");

      // Recovery: If we failed, we DO NOT nullify _apiInstance.
      // Why? The bridge might be fine, but the specific function failed.
      // Resetting _apiInstance would cause a "Double Singleton" crash on retry.

      return SatyaIdentity(did: "Error: $e", pubKey: "error");
    }
  }

  @override
  Future<String> scanQr(String rawCode) async {
    try {
      final rustApi = api;
      return await rustApi.rustScanQr(rawQrString: rawCode);
    } catch (e) {
      return '{"error": "$e"}';
    }
  }
}

IdentityRepository getIdentityRepository() => IdentityRepoNative();
