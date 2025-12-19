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
}