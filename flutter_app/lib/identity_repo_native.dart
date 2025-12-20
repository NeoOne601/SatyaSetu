/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * PHASE: 4.0 (Identity Lifecycle & Persistence)
 * DESCRIPTION: FFI Bridge Implementation with explicit namespacing.
 * PREVIOUS: Phase 3.3 (Secure FFI Bridge)
 */

import 'identity_domain.dart';
import 'identity_repo.dart';
// PRINCIPAL FIX: Using prefix 'bridge' to prevent namespace collision with local SatyaIdentity
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
      print("SATYA_FFI_ERROR: Vault initialization failed: $e");
      return false;
    }
  }

  @override
  Future<SatyaIdentity> createIdentity({String label = "Primary"}) async {
    try {
      // Mapping Rust Bridge Struct to Flutter Domain Class
      final result = await api.rustCreateIdentity(label: label);
      return SatyaIdentity(
        id: result.id,
        label: result.label,
        did: result.did,
      );
    } catch (e) {
      print("SATYA_FFI_ERROR: Identity creation failed: $e");
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
      print("SATYA_FFI_ERROR: Could not fetch identities: $e");
      return [];
    }
  }

  @override
  Future<String> scanQr(String rawCode) async {
    try {
      return await api.rustScanQr(rawQrString: rawCode);
    } catch (e) {
      return '{"error": "Rust FFI Scan Failure: $e"}';
    }
  }
}

IdentityRepository getIdentityRepository() => IdentityRepoNative();