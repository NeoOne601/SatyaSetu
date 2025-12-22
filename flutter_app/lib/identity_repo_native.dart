/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.9.9 (The Trinity Final Baseline)
 * VERSION: 1.5.8
 * STATUS: STABLE (Silent Loading)
 * DESCRIPTION:
 * Implements FFI calls. Prevents symbol re-loading noise and ensures 
 * high-performance signing logic on Android, iOS, and iMac.
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
        try {
          final dylib = DynamicLibrary.open(path);
          print("SATYA_DEBUG: Rust Core loaded from $path");
          return dylib;
        } catch (_) {}
      }
    }
    throw UnsupportedError('Rust Core binary missing. Run ./build_mobile.sh');
  }
}

class IdentityRepoNative implements IdentityRepository {
  static bridge.RustCoreImpl? _apiInstance;

  bridge.RustCoreImpl get api {
    if (_apiInstance != null) return _apiInstance!;
    final strategy = Platform.isAndroid 
        ? AndroidLoader() 
        : Platform.isMacOS ? MacOSLoader() : IOSLoader();
    _apiInstance = bridge.RustCoreImpl(strategy.loadLibrary());
    return _apiInstance!;
  }

  @override
  Future<bool> initializeVault(String pin, String hardwareId, String path) async {
    try {
      return await api.rustInitializeVault(pin: pin, hwId: hardwareId, storagePath: path);
    } catch (e) {
      print("SATYA_VAULT: Binding mismatch detected.");
      return false;
    }
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
    try { return await api.rustScanQr(rawQrString: rawCode); }
    catch (e) { return '{"error": "$e"}'; }
  }

  @override
  Future<String> signIntent(String identityId, String upiUrl) async {
    try { return await api.rustSignIntent(identityId: identityId, upiUrl: upiUrl); }
    catch (e) { return '{"error": "Rust signing failure: $e"}'; }
  }

  @override
  Future<bool> publishToNostr(String signedJson) async {
    try { return await api.rustPublishToNostr(signedJson: signedJson); }
    catch (e) { return false; }
  }
}

IdentityRepository getIdentityRepository() => IdentityRepoNative();