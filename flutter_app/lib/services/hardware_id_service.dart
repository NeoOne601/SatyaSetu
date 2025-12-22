/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.9 (Hardware Resilience Patch)
 * VERSION: 1.3.9
 * DESCRIPTION:
 * Stabilizes the hardware signature on macOS using systemGUID.
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareIdService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        // systemGUID is the stable Silicon-Binding for iMacs
        return macInfo.systemGUID ?? "macos_dev_stable";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "ios_dev_fallback"; 
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; 
      }
    } catch (e) {
      print("SATYA_SECURITY_WARN: Using fallback ID: $e");
    }
    return "satya_unbound_identity";
  }
}