/**
 * FILE: flutter_app/lib/identity_repo.dart
 * VERSION: 1.7.0
 * PHASE: Phase 7 (The Lens of Reality)
 * PURPOSE: Abstract contract for decentralized identity management.
 * DESCRIPTION:
 * Defines the capabilities of the Satya ledger, including vault initialization,
 * interaction signing, and the native forensic reset required for macOS.
 */

import 'identity_domain.dart';
import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  /// Fetches all personas (DIDs) currently stored in the secure vault.
  Future<List<SatyaIdentity>> getIdentities();

  /// Generates a new persona-based identity (e.g., 'Commuter', 'Student', 'Merchant').
  Future<SatyaIdentity> createIdentity({String label = "Primary"});

  /// Parses a raw QR string into a structured interaction intent using Rust Regex.
  Future<String> scanQr(String rawCode);

  /// Unlocks the vault using a PIN and binds it to the device's unique hardware ID.
  Future<bool> initializeVault(String pin, String hardwareId, String path);

  /// Generates an Ed25519 signature for an interaction and packages it as JSON.
  Future<String> signIntent(String identityId, String upiUrl);

  /// Broadcasts a signed Interaction Proof (Kind 29001) to the Nostr network.
  Future<bool> publishToNostr(String signedJson);
  
  /// PRINCIPAL FIX: Trigger native cryptographic purge and rename to resolve macOS locks.
  Future<bool> resetVault(String path);

  /// Factory constructor to return the platform-specific implementation.
  factory IdentityRepository() => getIdentityRepository();
}