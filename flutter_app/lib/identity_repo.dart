/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 4.0 (Identity Lifecycle & Persistence)
 * VERSION: 1.1.0
 * STATUS: STABLE
 * DESCRIPTION:
 * The primary contract for identity operations. Uses conditional imports 
 * to switch between Native (FFI) and Stub implementations.
 * CHANGE LOG:
 * - Phase 2.0: Added scanQr contract.
 * - Phase 3.3: Added initializeVault contract.
 * - Phase 4.0: Standardized Phase headers and persistence workflow.
 */

import 'identity_domain.dart';
import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  /// Retrieves all saved identities from the local secure vault
  Future<List<SatyaIdentity>> getIdentities();

  /// Creates a new Decentralized Identity with a custom label
  Future<SatyaIdentity> createIdentity({String label = "Primary"});
  
  /// Processes a raw QR string through the Rust core UPI parser
  Future<String> scanQr(String rawCode);
  
  /// Initializes Secure Persistence with Silicon-Binding (AAD)
  /// Unlocks the secure vault using the user PIN and hardware binding.
  /// [pin]: The user's secret code.
  /// [hardwareId]: The unique silicon ID of the device (AAD).
  /// [path]: The sandbox path where 'vault.bin' resides.
  Future<bool> initializeVault(String pin, String hardwareId, String path);

  factory IdentityRepository() => getIdentityRepository();
}