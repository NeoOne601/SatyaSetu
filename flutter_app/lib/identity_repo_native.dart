/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 4.0 (Identity Lifecycle & Persistence)
 * VERSION: 1.1.0
 * STATUS: STABLE (Silicon-Locked)
 * * DESCRIPTION:
 * Implements the FFI bridge between Flutter and the Rust Core. 
 * Maps native Rust structs into local Dart Domain models using namespacing.
 * * CHANGE LOG:
 * - Phase 3.3: Initial Secure FFI implementation.
 * - Phase 3.6: Android Parity Sync (JNI linking verified).
 * - Phase 4.0: Standardized Documentation headers and model mapping.
 */

import 'identity_domain.dart';
import 'identity_repo.dart';
// PRINCIPAL FIX: Namespace 'bridge' prevents collisions with local domain classes
import 'bridge_generated.dart' as bridge;
import 'dart:ffi';
import 'dart:io';

// ==============================================================================
// STRATEGY PATTERN: PLATFORM LOADING
// ==============================================================================
abstract class RustLoaderStrategy {
  DynamicLibrary loadLibrary();
}

class AndroidLoader implements RustLoaderStrategy {
  @override
  DynamicLibrary loadLibrary() => DynamicLibrary.open('librust_core.so');
}

class IOSLoader implements RustLoaderStrategy {
  @override
  DynamicLibrary loadLibrary() => DynamicLibrary.process();
}

class RustLoaderFactory {
  static RustLoaderStrategy getStrategy() {
    if (Platform.isAndroid) return AndroidLoader();
    if (Platform.isIOS) return IOSLoader();
    throw UnsupportedError('Platform not supported for Native Rust Loader');
  }
}

// ==============================================================================
// REPOSITORY IMPLEMENTATION
// ==============================================================================
class IdentityRepoNative implements IdentityRepository {
  static bridge.RustCoreImpl? _apiInstance;

  bridge.RustCoreImpl get api {
    if (_apiInstance != null) return _apiInstance!;
    final strategy = RustLoaderFactory.getStrategy();
    final dylib = strategy.loadLibrary();
    _apiInstance = bridge.RustCoreImpl(dylib);
    return _apiInstance!;
  }

  @override
  Future<bool> initializeVault(String pin, String hardwareId, String path) async {
    try {
      return await api.rustInitializeVault(
        pin: pin,
        hwId: hardwareId,
        storagePath: path,
      );
    } catch (e) {
      print("SATYA_FFI_ERROR: Vault initialization failure: $e");
      return false;
    }
  }

  @override
  Future<SatyaIdentity> createIdentity({String label = "Primary"}) async {
    try {
      // PRINCIPAL DESIGN: Mapping Bridge Struct to local Domain Class
      final result = await api.rustCreateIdentity(label: label);
      return SatyaIdentity(
        id: result.id,
        label: result.label,
        did: result.did,
      );
    } catch (e) {
      print("SATYA_FFI_ERROR: Identity generation failure: $e");
      return SatyaIdentity(id: "error", label: "Error", did: "did:error:$e");
    }
  }

  @override
  Future<List<SatyaIdentity>> getIdentities() async {
    try {
      final results = await api.rustGetIdentities();
      return results.map((r) => SatyaIdentity(
        id: r.id,
        label: r.label,
        did: r.did
      )).toList();
    } catch (e) {
      print("SATYA_FFI_ERROR: Ledger synchronization failed: $e");
      return [];
    }
  }

  @override
  Future<String> scanQr(String rawCode) async {
    try {
      return await api.rustScanQr(rawQrString: rawCode);
    } catch (e) {
      return '{"error": "Rust FFI Parsing Error: $e"}';
    }
  }
}

IdentityRepository getIdentityRepository() => IdentityRepoNative();