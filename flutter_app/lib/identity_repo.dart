/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.7 (macOS Native Recovery)
 * VERSION: 1.3.6
 * STATUS: STABLE (Architectural Baseline)
 * DESCRIPTION:
 * Abstract contract for Identity operations. Defines the interface 
 * for the Silicon-Locked Rust implementation across all platforms.
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

  factory IdentityRepository() => getIdentityRepository();
}