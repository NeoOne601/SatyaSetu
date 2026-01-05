/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 3.0.0
 * PHASE: Phase 61.2 (Tri-Card General Intelligence)
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION:
 * 1. resolveInstant: 2 cards provided by local Florence (No Lag).
 * 2. fetchInquiries: 1 card provided by local Gemma (Background).
 * 3. Distinct Coloration: Deterministic neon hashing for every label.
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  /// INSTANT PERCEPTION: Generates the first 2 cards immediately from Florence detection.
  static SituationState resolveInstant(String label, String sceneContext) {
    final Color dynamicColor = generateVibrantColor(label);
    
    return SituationState(
      title: "Physical Perception",
      context: SituationContext.global,
      themeColor: dynamicColor,
      actions: [
        MorphicAction(
          label: "Visual Ground Truth", 
          icon: LucideIcons.eye, 
          description: "Florence confirm: $label",
          payloadType: "info",
          onExecute: (c) => {}
        ),
        MorphicAction(
          label: "Environmental Logic", 
          icon: LucideIcons.packageSearch, 
          description: "Object role in $sceneContext",
          payloadType: "info",
          onExecute: (c) => {}
        ),
      ],
    );
  }

  /// COGNITIVE INQUIRY: Fetches relatable questions from the local Gemma brain.
  static Future<List<String>> fetchInquiries(String label, String sceneContext) async {
    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/v1/reason"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"object": label, "context": sceneContext})
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['questions']);
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [REASONER] Gemma logic stutter.");
    }
    return ["Synthesizing $label insights..."];
  }

  /// DETERMINISTIC VIBRANT COLORATION: Ensures distinct boxes on the fly.
  static Color generateVibrantColor(String text) {
    final int hash = text.hashCode;
    // Maps label string to a consistent, bright neon hue
    return HSVColor.fromAHSV(1.0, (hash % 360).toDouble(), 0.8, 0.95).toColor();
  }
}