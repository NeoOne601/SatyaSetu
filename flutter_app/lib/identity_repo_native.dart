/**
 * FILE: flutter_app/lib/identity_repo_native.dart
 * VERSION: 1.13.0
 * PHASE: Phase 13 (Nostr Protocol Integration)
 * PURPOSE: Implements Nostr event signing and broadcast via Rust FFI.
 * CHANGES: Added signEvent, broadcastEvent, subscribeEvents methods.
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
    
    final DynamicLibrary dl;
    
    if (Platform.isIOS) {
      // iOS: The Rust library is statically linked into the Runner executable.
      // We must use .process() to load symbols from the main process.
      dl = DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      // macOS: Loads from the separate dynamic library file.
      dl = DynamicLibrary.open('librust_core.dylib');
    } else {
      // Android: Loads from the shared object file.
      dl = DynamicLibrary.open('librust_core.so');
    }

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
  
  // --- PHASE 13: NOSTR EVENT SIGNING ---
  
  /// Sign an arbitrary payload as a Nostr event
  /// [identityId] - The identity to sign with
  /// [eventKind] - Nostr event kind (1040=Ads, 1985=Reviews, 29001=Intents)
  /// [payloadJson] - The JSON payload to sign
  @override
  Future<String> signEvent(String identityId, int eventKind, String payloadJson) => 
    api.rustSignEvent(identityId: identityId, eventKind: eventKind, payloadJson: payloadJson);
  
  /// Broadcast a pre-signed event to Nostr relays
  @override
  Future<bool> broadcastEvent(String signedEventJson) => 
    api.rustBroadcastEvent(signedEventJson: signedEventJson);
  
  /// Subscribe to Nostr events matching criteria
  /// [kinds] - List of event kinds to filter
  /// [authorPubkey] - Optional author public key filter
  /// [limit] - Maximum number of events to return
  @override
  Future<List<String>> subscribeEvents(List<int> kinds, {String? authorPubkey, int limit = 20}) => 
    api.rustSubscribeEvents(kinds: kinds.map((k) => k).toList(), authorPubkey: authorPubkey, limit: limit);
}

IdentityRepository getIdentityRepository() => IdentityRepoNative();