/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 6.8 (Forensic Synchronization)
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
  
  /// Trigger native cryptographic purge and rename to resolve filesystem locks
  Future<bool> resetVault(String path);

  factory IdentityRepository() => getIdentityRepository();
}