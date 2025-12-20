/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 4.0 (Identity Lifecycle & Persistence)
 * VERSION: 1.1.0
 * STATUS: STABLE
 * DESCRIPTION:
 * Fetches unique hardware signatures to use as Additional Authenticated 
 * Data (AAD) for binary vault encryption.
 * CHANGE LOG:
 * - Phase 3.3: Initial Silicon ID extraction logic.
 * - Phase 4.0: Standardized Phase headers and error state fallbacks.
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareIdService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "ios_dev_fallback"; 
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; 
      }
    } catch (e) {
      print("SATYA_SECURITY_WARN: Silicon Binding fallback active: $e");
    }
    
    return "satya_generic_dev_id";
  }
}