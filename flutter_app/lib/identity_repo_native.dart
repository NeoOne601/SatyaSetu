/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.2.5
 * STATUS: STABLE (FFI Linked)
 * DESCRIPTION:
 * Low-level implementation of the IdentityRepository using 
 * flutter_rust_bridge. Maps native Rust types into Dart domain models.
 */

import 'identity_domain.dart';
import 'identity_repo.dart';
// Namespacing 'bridge' prevents naming collisions with local domain models.
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
    throw UnsupportedError('Unsupported platform for native Rust Core');
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
      return await api.rustInitializeVault(pin: pin, hwId: hardwareId, storagePath: path);
    } catch (e) {
      print("SATYA_FFI_ERROR: Vault unlock failure: $e");
      return false;
    }
  }

  @override
  Future<SatyaIdentity> createIdentity({String label = "Primary"}) async {
    try {
      final result = await api.rustCreateIdentity(label: label);
      return SatyaIdentity(id: result.id, label: result.label, did: result.did);
    } catch (e) {
      return SatyaIdentity(id: "error", label: "Error", did: "did:error:$e");
    }
  }

  @override
  Future<List<SatyaIdentity>> getIdentities() async {
    try {
      final results = await api.rustGetIdentities();
      return results.map((r) => SatyaIdentity(id: r.id, label: r.label, did: r.did)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String> scanQr(String rawCode) async {
    try {
      return await api.rustScanQr(rawQrString: rawCode);
    } catch (e) {
      return '{"error": "$e"}';
    }
  }

  @override
  Future<String> signIntent(String identityId, String upiUrl) async {
    try {
      return await api.rustSignIntent(identityId: identityId, upiUrl: upiUrl);
    } catch (e) {
      return '{"error": "Rust signing failure: $e"}';
    }
  }
}

/// Global builder function used by the IdentityRepository factory
IdentityRepository getIdentityRepository() => IdentityRepoNative();