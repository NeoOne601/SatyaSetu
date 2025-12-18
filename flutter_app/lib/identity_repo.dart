import 'identity_domain.dart';

import 'identity_repo_stub.dart'
    if (dart.library.io) 'identity_repo_native.dart'
    if (dart.library.html) 'identity_repo_web.dart';

abstract class IdentityRepository {
  Future<SatyaIdentity> createIdentity();
  // NEW FOR SCANNING QR
  Future<String> scanQr(String rawCode);

  factory IdentityRepository() => getIdentityRepository();
}
