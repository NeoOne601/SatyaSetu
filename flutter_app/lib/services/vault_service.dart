/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.2.2
 * STATUS: STABLE
 * DESCRIPTION:
 * Orchestrates the secure vault lifecycle. Decouples UI from the 
 * Repository and maintains volatile session state.
 * CHANGE LOG:
 * - Phase 4.0: Identity persistence workflows finalized.
 * - Phase 5.0: Standardized Phase headers.
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
      return false;
    }
  }

  void lock() {
    _isUnlocked = false;
  }

  Future<SatyaIdentity?> createNewIdentity(String label) async {
    if (!_isUnlocked) return null;
    return await _repo.createIdentity(label: label);
  }
}