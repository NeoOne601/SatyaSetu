/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 6.6 (Forensic Baseline)
 * VERSION: 1.6.6
 * DESCRIPTION:
 * Harmonizes hardware signatures for Android, iOS, and macOS.
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareIdService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        // systemGUID is the golden standard for sandboxed macOS apps
        final id = macInfo.systemGUID ?? "macos_stable_static_id";
        print("SATYA_DEBUG: Hardware ID (macOS): $id");
        return id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "ios_stable_id"; 
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final baseId = androidInfo.id;
        if (baseId == "android_id" || baseId.isEmpty) {
           return "android_emu_${androidInfo.model}";
        }
        return baseId;
      }
    } catch (e) {
      print("SATYA_SECURITY: ID Extraction Warning: $e");
    }
    return "satya_unbound_identity";
  }
}