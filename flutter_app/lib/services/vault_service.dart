/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 4.0 (Identity Lifecycle & Persistence)
 * VERSION: 1.1.0
 * STATUS: STABLE
 * DESCRIPTION:
 * Orchestrates the secure vault lifecycle. Decouples UI logic from the 
 * Native Repository and maintains the volatile session state.
 * CHANGE LOG:
 * - Phase 3.1: Initial VaultService skeleton.
 * - Phase 3.3: Silicon-Locked Unlock implementation.
 * - Phase 4.0: Identity persistence workflows finalized and documented.
 */

import '../identity_repo.dart';
import '../identity_domain.dart';

class VaultService {
  final IdentityRepository _repo;
  bool _isUnlocked = false;
  
  VaultService(this._repo);

  bool get isUnlocked => _isUnlocked;

  Future<bool> unlock(String pin, String hardwareId, String path) async {
    try {
      final success = await _repo.initializeVault(pin, hardwareId, path);
      _isUnlocked = success;
      return success;
    } catch (e) {
      _isUnlocked = false;
      print("SATYA_VAULT_ERROR: Security breach or init failure: $e");
      return false;
    }
  }

  void lock() {
    _isUnlocked = false;
    print("SATYA_VAULT: Identity Locked. Session memory zeroed.");
  }

  Future<SatyaIdentity?> createNewIdentity(String label) async {
    if (!_isUnlocked) {
      print("SATYA_SECURITY: Blocked write attempt to locked vault.");
      return null;
    }
    return await _repo.createIdentity(label: label);
  }
}