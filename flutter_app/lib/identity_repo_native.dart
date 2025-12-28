/**
 * FILE: flutter_app/lib/identity_repo_native.dart
 * VERSION: 1.9.4
 * PHASE: Phase 8.2
 * PURPOSE: Implements History Fetching and FFI stability.
 */

import 'identity_domain.dart';
import 'identity_repo.dart';
import 'bridge_generated.dart' as bridge;
import 'dart:ffi';
import 'dart:io';

class IdentityRepoNative implements IdentityRepository {
  static bridge.RustCoreImpl? _api;

  bridge.RustCoreImpl get api {
    if (_api != null) return _api!;
    final dl = Platform.isMacOS 
      ? DynamicLibrary.open('librust_core.dylib') 
      : DynamicLibrary.open('librust_core.so');
    _api = bridge.RustCoreImpl(dl);
    return _api!;
  }

  @override Future<bool> initializeVault(p, h, s) => api.rustInitializeVault(pin: p, hwId: h, storagePath: s);
  @override Future<bool> resetVault(s) => api.rustResetVault(storagePath: s);
  @override Future<SatyaIdentity> createIdentity({label = "Primary"}) async {
    final r = await api.rustCreateIdentity(label: label);
    return SatyaIdentity(id: r.id, label: r.label, did: r.did);
  }
  @override Future<List<SatyaIdentity>> getIdentities() async {
    final list = await api.rustGetIdentities();
    return list.map((r) => SatyaIdentity(id: r.id, label: r.label, did: r.did)).toList();
  }
  @override Future<String> scanQr(c) => api.rustScanQr(rawQrString: c);
  @override Future<String> signIntent(i, u) => api.rustSignIntent(identityId: i, upiUrl: u);
  @override Future<bool> publishToNostr(s) => api.rustPublishToNostr(signedJson: s);
  @override Future<List<String>> fetchInteractionHistory() => api.rustFetchInteractionHistory();
}

IdentityRepository getIdentityRepository() => IdentityRepoNative();