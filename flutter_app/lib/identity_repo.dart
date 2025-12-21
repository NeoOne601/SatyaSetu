/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.2.2
 * STATUS: ARCHITECTURAL BASELINE
 * DESCRIPTION:
 * Defines the abstract interface for all identity operations. 
 * Coordinates the conditional injection of native FFI logic.
 * CHANGE LOG:
 * - Phase 4.0: Identity Ledger persistence baselined.
 * - Phase 5.0: Added signIntent contract for cryptographic proofs.
 */

import 'identity_domain.dart';
// PRINCIPAL DESIGN: Conditional injection based on platform availability
import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  /// Retrieves all saved identities from the local secure vault
  Future<List<SatyaIdentity>> getIdentities();

  /// Creates a new Decentralized Identity with a custom label and Ed25519 keypair
  Future<SatyaIdentity> createIdentity({String label = "Primary"});
  
  /// Processes a raw QR string through the Rust core UPI parser
  Future<String> scanQr(String rawCode);
  
/// Initializes Secure Persistence with Silicon-Binding (AAD)
  /// Unlocks the secure vault using the user PIN and hardware binding.
  /// [pin]: The user's secret code.
  /// [hardwareId]: The unique silicon ID of the device (AAD).
  /// [path]: The sandbox path where 'vault.bin' resides.

  Future<bool> initializeVault(String pin, String hardwareId, String path);

  /// Cryptographically sign a UPI intent using the persistent Rust vault
  Future<String> signIntent(String identityId, String upiUrl);

  /// Factory constructor to inject the platform-specific implementation
  factory IdentityRepository() => getIdentityRepository();
}