/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.2.5
 * STATUS: STABLE (Surgical Separation Baseline)
 * DESCRIPTION:
 * Abstract interface for identity operations. Manages the conditional 
 * platform-specific injection of the Rust Core implementation.
 * CHANGE LOG:
 * - Phase 4.0: Identity persistence baseline.
 * - Phase 5.0: Ed25519 signIntent contract and architectural separation.
 */

import 'identity_domain.dart';
// PRINCIPAL DESIGN: Injects the implementation only at compile-time 
// based on the target platform (Mobile vs Web vs Stub).
import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  /// Fetches all identities from the Silicon-Locked Rust vault.
  Future<List<SatyaIdentity>> getIdentities();

  /// Generates a new identity with a unique Ed25519 signing keypair.
  Future<SatyaIdentity> createIdentity({String label = "Primary"});
  
  /// Parses a raw UPI URL string through the Rust Regex engine.
  Future<String> scanQr(String rawCode);
  
  /// Authenticates the user and unlocks the binary vault using Argon2 KDF.
  Future<bool> initializeVault(String pin, String hardwareId, String path);

  /// Signs a JSON intent using the private key associated with the ID.
  Future<String> signIntent(String identityId, String upiUrl);

  /// Factory constructor pointing to the platform-specific builder.
  factory IdentityRepository() => getIdentityRepository();
}