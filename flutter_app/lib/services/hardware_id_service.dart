/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.5.0
 * DESCRIPTION:
 * Stabilizes hardware signatures across the "Trinity" (Android, iOS, iMac).
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareIdService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.systemGUID ?? "macos_dev_stable";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "ios_dev_fallback"; 
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; 
      }
    } catch (e) {
      print("SATYA_SECURITY: Fallback ID active.");
    }
    return "satya_unbound_identity";
  }
}