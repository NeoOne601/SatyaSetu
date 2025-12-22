/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.6 (Desktop & Web Parity Sync)
 * VERSION: 1.2.7
 * STATUS: STABLE (Safari/Chrome Fallback)
 * DESCRIPTION:
 * Web-based fallback implementation. Cross-platform parity for 
 * non-native environments.
 */

import 'identity_domain.dart';
import 'identity_repo.dart';

class IdentityRepoWeb implements IdentityRepository {
  @override
  Future<bool> initializeVault(String pin, String hardwareId, String path) async {
    print("SATYA_WEB_WARN: Persistence is restricted on Web targets.");
    return false;
  }

  @override
  Future<SatyaIdentity> createIdentity({String label = "Primary"}) async {
    return SatyaIdentity(
      id: "web_stub", 
      label: "Web Feature Restricted", 
      did: "did:satya:web:unsupported"
    );
  }

  @override
  Future<List<SatyaIdentity>> getIdentities() async => [];

  @override
  Future<String> scanQr(String rawCode) async => 
      '{"error": "Vampire Scanner requires Native NDK/Vision APIs"}';

  @override
  Future<String> signIntent(String identityId, String upiUrl) async =>
      '{"error": "Ed25519 Signing requires Native Rust Core"}';
}

IdentityRepository getIdentityRepository() => IdentityRepoWeb();