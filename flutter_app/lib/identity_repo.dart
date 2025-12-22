/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.9.6 (iMac Stability Baseline)
 * VERSION: 1.5.1
 * STATUS: STABLE (Architectural Standard)
 * DESCRIPTION:
 * Defines the abstract interface for identity and signing operations.
 * Manages the Trinity Pipeline (Android, iOS, macOS) injection.
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