import 'identity_domain.dart';
import 'identity_repo.dart';

class IdentityRepoWeb implements IdentityRepository {
  @override
  Future<SatyaIdentity> createIdentity() async {
    return SatyaIdentity(did: "web_mock_did", pubKey: "web");
  }

  @override
  Future<String> scanQr(String rawCode) async {
    return '{"status": "Web Mock: Scanned $rawCode"}';
  }
}

IdentityRepository getIdentityRepository() => IdentityRepoWeb();
