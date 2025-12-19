// Adding Persistence and Security
import 'identity_domain.dart';

import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  /// Retrieves identities from the local secure vault
  Future<List<SatyaIdentity>> getIdentities();

  /// Creates a new Decentralized Identity
  Future<SatyaIdentity> createIdentity({String label = "Primary"});
  
  /// Processes a raw QR string through the Rust core
  Future<String> scanQr(String rawCode);
  
  /// New Phase 3 Method: Initialize Secure Persistence
  /// - [pin]: User-defined PIN for key derivation (Argon2id)
  /// - [hardwareId]: The silicon-binding signature (AAD)
  /// - [path]: The secure application sandbox path for storage
  Future<bool> initializeVault(String pin, String hardwareId, String path);

  factory IdentityRepository() => getIdentityRepository();
}