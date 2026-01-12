/**
 * FILE: flutter_app/lib/services/uts_api_service.dart
 * VERSION: 1.0.0
 * PHASE: Phase 10.3 (SaaS Logic)
 * DESCRIPTION: Connects to the Central UTS to fetch Sector-Specific APE Logic.
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class UtsApiService {
  // Point this to your iMac IP in production testing
  static const String _baseUrl = "http://192.168.0.174:8000"; // IMacIP 192.168.0.174 //192.168.1.15
  static Future<Map<String, dynamic>> fetchSaaSLogic(String sector) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/v1/uts/logic?sector=$sector"),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return _getLocalFallback(sector);
    } catch (e) {
      debugPrint("UTS_ERROR: Failed to fetch SaaS logic: $e");
      return _getLocalFallback(sector);
    }
  }

  static Future<Map<String, dynamic>> crossReferenceIdentity(String label) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/v1/vision/match"),
        body: jsonEncode({"label": label}),
        headers: {"Content-Type": "application/json"}
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // silent fail
    }
    return {};
  }

  static Map<String, dynamic> _getLocalFallback(String sector) {
    return {
      "checklist": [{"step": 1, "instruction": "Standard Identity Check", "recordable": true}],
      "weight": {"general": 1.0}
    };
  }
}