// Adding Persistence and Security
import '../identity_repo.dart';
import '../identity_domain.dart';

/// PRINCIPAL DESIGN: Vault Orchestrator (State Management)
/// This service manages the lifecycle of the Secure Vault. 
/// It adheres to SOLID principles by decoupling the UI from raw Repository calls.
class VaultService {
  final IdentityRepository _repo;
  
  /// Internal state tracking if the Rust vault is currently decrypted in RAM.
  bool _isUnlocked = false;
  
  VaultService(this._repo);

  /// Getter for UI components to determine current security state.
  bool get isUnlocked => _isUnlocked;

  /// Unlocks the secure vault using the user PIN and hardware binding.
  /// [pin]: The user's secret code.
  /// [hardwareId]: The unique silicon ID of the device (AAD).
  /// [path]: The sandbox path where 'vault.bin' resides.
  Future<bool> unlock(String pin, String hardwareId, String path) async {
    try {
      // Passes parameters to the Native Bridge -> Rust Core.
      final success = await _repo.initializeVault(pin, hardwareId, path);
      
      _isUnlocked = success;
      
      if (success) {
        print("SATYA_VAULT: Silicon-Locked access granted.");
      } else {
        print("SATYA_VAULT: Access denied - Hardware/PIN mismatch.");
      }
      
      return success;
    } catch (e) {
      _isUnlocked = false;
      print("SATYA_VAULT_ERROR: Security breach or initialization failure: $e");
      return false;
    }
  }

  /// Zeroes out the local session state. 
  /// Note: The actual memory wipe happens in Rust when the bridge session ends.
  void lock() {
    _isUnlocked = false;
    print("SATYA_VAULT: Session locked. Data encrypted at rest.");
  }

  /// Creates a new identity and performs an atomic save to the binary vault.
  Future<SatyaIdentity?> createNewIdentity(String label) async {
    if (!_isUnlocked) {
      print("SATYA_SECURITY: Attempted to create identity while vault is locked.");
      return null;
    }
    return await _repo.createIdentity(label: label);
  }
}