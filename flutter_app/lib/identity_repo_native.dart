/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 6.0 (The Decentralized Proof)
 * VERSION: 1.6.0
 * STATUS: STABLE (Nostr Mapping Enabled)
 */

import 'identity_domain.dart';
import 'identity_repo.dart';
import 'bridge_generated.dart' as bridge;
import 'dart:ffi';
import 'dart:io';

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

class MacOSLoader implements RustLoaderStrategy {
  @override
  DynamicLibrary loadLibrary() {
    final paths = [
      'librust_core.dylib',
      'macos/librust_core.dylib',
      '${File(Platform.resolvedExecutable).parent.path}/../Frameworks/librust_core.dylib',
    ];
    for (var path in paths) {
      if (File(path).existsSync() || path == 'librust_core.dylib') {
        try { return DynamicLibrary.open(path); } catch (_) {}
      }
    }
    throw UnsupportedError('Rust binary missing.');
  }
}

class IdentityRepoNative implements IdentityRepository {
  static bridge.RustCoreImpl? _apiInstance;

  bridge.RustCoreImpl get api {
    if (_apiInstance != null) return _apiInstance!;
    final strategy = Platform.isAndroid ? AndroidLoader() : Platform.isMacOS ? MacOSLoader() : IOSLoader();
    _apiInstance = bridge.RustCoreImpl(strategy.loadLibrary());
    return _apiInstance!;
  }

  @override
  Future<bool> initializeVault(String pin, String hardwareId, String path) async {
    try { return await api.rustInitializeVault(pin: pin, hwId: hardwareId, storagePath: path); } catch (e) { return false; }
  }

  @override
  Future<SatyaIdentity> createIdentity({String label = "Primary"}) async {
    try {
      final result = await api.rustCreateIdentity(label: label);
      return SatyaIdentity(id: result.id, label: result.label, did: result.did);
    } catch (e) { return SatyaIdentity(id: "err", label: "Error", did: "err"); }
  }

  @override
  Future<List<SatyaIdentity>> getIdentities() async {
    try {
      final results = await api.rustGetIdentities();
      return results.map((r) => SatyaIdentity(id: r.id, label: r.label, did: r.did)).toList();
    } catch (e) { return []; }
  }

  @override
  Future<String> scanQr(String rawCode) async {
    try { return await api.rustScanQr(rawQrString: rawCode); } catch (e) { return '{"error": "$e"}'; }
  }

  @override
  Future<String> signIntent(String identityId, String upiUrl) async {
    try { return await api.rustSignIntent(identityId: identityId, upiUrl: upiUrl); } catch (e) { return '{"error": "$e"}'; }
  }

  @override
  Future<bool> publishToNostr(String signedJson) async {
    try { 
      // Real FFI call to Phase 6 Rust Engine
      return await api.rustPublishToNostr(signedJson: signedJson); 
    } catch (e) { 
      print("SATYA_FFI_NOSTR: $e");
      return false; 
    }
  }
}

IdentityRepository getIdentityRepository() => IdentityRepoNative();