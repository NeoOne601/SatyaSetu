/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.9.9 (Final Trinity Baseline)
 * VERSION: 1.5.8
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareIdService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.systemGUID ?? "macos_stable_id";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "ios_stable_id"; 
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Principal Fix: Emulator detection to provide stable ID during development
        final baseId = androidInfo.id;
        if (baseId == "android_id" || baseId.isEmpty) {
           return "android_emu_${androidInfo.model}";
        }
        return baseId;
      }
    } catch (e) {
      print("SATYA_SECURITY: ID Fallback active.");
    }
    return "satya_generic_id";
  }
}