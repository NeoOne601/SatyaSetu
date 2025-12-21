/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.2.2
 * STATUS: STABLE (FFI Linking Verified)
 * DESCRIPTION:
 * Implements FFI calls to the Rust Core. Private keys never leave Rust.
 * CHANGE LOG:
 * - Phase 3.6: Android Parity Sync baselined.
 * - Phase 4.0: Identity Ledger sync and namespace-collision fix.
 * - Phase 5.0: Implementation of 'signIntent' FFI bridge mapping.
 */

import 'identity_domain.dart';
import 'identity_repo.dart';
// Namespacing 'bridge' prevents collisions with local SatyaIdentity domain model
import 'bridge_generated.dart' as bridge;
import 'dart:ffi';
import 'dart:io';

// --- Loading Strategies ---
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
    throw UnsupportedError('Unsupported platform for Rust Core');
  }
}

// --- Implementation ---
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
      return '{"error": "Signing failure: $e"}';
    }
  }
}

/// Factory hook used by identity_repo.dart
IdentityRepository getIdentityRepository() => IdentityRepoNative();