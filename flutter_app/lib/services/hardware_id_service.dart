// Adding Persistence and Security
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// PRINCIPAL DESIGN: Silicon Identity Provider
/// Fetches a unique hardware signature to use as AAD (Additional Authenticated Data)
/// for the Rust XChaCha20-Poly1305 encryption.
class HardwareIdService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // identifierForVendor is stable and persistent on iOS
        return iosInfo.identifierForVendor ?? "ios_dev_fallback"; 
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; 
      }
    } catch (e) {
      print("SATYA_SECURITY_WARN: Hardware ID fetch failed, using fallback: $e");
    }
    
    return "satya_default_dev_id";
  }
}