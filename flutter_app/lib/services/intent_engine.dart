/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 6.0.0
 * PHASE: Phase 76.3 (Logic Recovery)
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: 
 * 1. Restored fetchAffordances logic for on-demand APE planning.
 * 2. Synchronized data models with Version 7.0.0 of intent_models.dart.
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  /// CHOICE TIER 1: Instant perception verification.
  static SituationState resolveInstant(String label) {
    return SituationState(
      title: "Handshake Active",
      actions: [],
      themeColor: generateVibrantColor(label),
      context: SituationContext.global,
    );
  }

  /// CHOICE TIER 2: Async APE planning from Gemma.
  static Future<ApeResponse> fetchAffordances(String label, String context) async {
    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/v1/reason"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "object": {"label": label, "confidence": 0.99},
          "context": context,
          "allowed_affordances": ["inspect", "usage", "record_interaction"]
        }),
      ).timeout(const Duration(seconds: 25)); // Deep planning allowed more time

      if (response.statusCode == 200) {
        return ApeResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("APE_HANDSHAKE_DELAY: $e");
    }
    return ApeResponse.empty(label: label, context: context);
  }

  static Color generateVibrantColor(String text) {
    return HSVColor.fromAHSV(1.0, (text.hashCode % 360).toDouble(), 0.8, 0.95).toColor();
  }
}