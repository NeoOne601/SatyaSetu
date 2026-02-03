/**
 * FILE: flutter_app/lib/identity_repo.dart
 * VERSION: 1.13.0
 * PHASE: Phase 13 (Nostr Protocol Integration)
 * GOAL: Defines the contract for identity and Nostr operations.
 */

import 'identity_domain.dart';
import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  Future<List<SatyaIdentity>> getIdentities();
  Future<SatyaIdentity> createIdentity({String label = "Primary"});
  Future<String> scanQr(String rawCode);
  Future<bool> initializeVault(String pin, String hardwareId, String path);
  Future<String> signIntent(String identityId, String upiUrl);
  Future<bool> publishToNostr(String signedJson);
  Future<bool> resetVault(String path);
  Future<List<String>> fetchInteractionHistory();
  
  // Phase 13: Nostr Event Signing
  Future<String> signEvent(String identityId, int eventKind, String payloadJson);
  Future<bool> broadcastEvent(String signedEventJson);
  Future<List<String>> subscribeEvents(List<int> kinds, {String? authorPubkey, int limit = 20});

  factory IdentityRepository() => getIdentityRepository();
}