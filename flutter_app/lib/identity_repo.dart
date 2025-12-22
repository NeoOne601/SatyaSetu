/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.9.9 (The Trinity Final Baseline)
 * VERSION: 1.5.8
 * STATUS: STABLE (Architectural Standard)
 * DESCRIPTION:
 * Abstract contract for Identity operations. Manages the conditional 
 * platform-specific injection of the Silicon-Locked Rust implementation.
 */

import 'identity_domain.dart';
import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  /// Retrieves all identities from the local secure vault.
  Future<List<SatyaIdentity>> getIdentities();

  /// Generates a new identity with a unique Ed25519 signing keypair.
  Future<SatyaIdentity> createIdentity({String label = "Primary"});
  
  /// Parses a raw QR string through the native Rust Regex engine.
  Future<String> scanQr(String rawCode);
  
  /// Authenticates the user and unlocks the binary vault using Argon2id.
  Future<bool> initializeVault(String pin, String hardwareId, String path);

  /// Cryptographically signs a scanned intent via Rust Core.
  Future<String> signIntent(String identityId, String upiUrl);

  /// Broadcasts a signed interaction to global relays (Nostr Integration).
  Future<bool> publishToNostr(String signedJson);

  factory IdentityRepository() => getIdentityRepository();
}