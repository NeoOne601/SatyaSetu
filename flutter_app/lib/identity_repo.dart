/**
 * FILE: flutter_app/lib/identity_repo.dart
 * VERSION: 1.9.4
 * PHASE: Phase 8.2
 * GOAL: Maintain the Proof Fetching contract for decentralized history.
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

  factory IdentityRepository() => getIdentityRepository();
}