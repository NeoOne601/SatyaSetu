/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 3.9.0
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Implements the "2+3" Choice Separation.
 * Florence choices (Internal/Heuristic) + Gemma choices (External/LLM).
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  /// CHOICE TIER 1: FLORENCE (Heuristic / Fast / Standardized)
  static SituationState resolveInstant(String label) {
    final String l = label.toUpperCase();
    final Color color = generateVibrantColor(l);
    
    // Heuristic Map for instant engagement
    List<MorphicAction> choices = [
      MorphicAction(
        label: "Visual Ground Truth", 
        icon: LucideIcons.eye, 
        description: "Standard physical verification of $label",
        payloadType: "info",
        onExecute: (c) => {}
      ),
      MorphicAction(
        label: "Registry Audit", 
        icon: LucideIcons.database, 
        description: "Index $label to local ledger",
        payloadType: "info",
        onExecute: (c) => {}
      ),
    ];

    return SituationState(title: "Perception Tier", actions: choices, themeColor: color, context: SituationContext.global);
  }

  /// CHOICE TIER 2: GEMMA (Advanced / LLM / Async)
  static Future<List<String>> fetchInquiries(String label, String sceneContext) async {
    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/v1/reason"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"object": label, "context": sceneContext})
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['questions']);
      }
    } catch (e) {}
    return ["Utility of $label?", "Origin of $label?", "Value of $label?"];
  }

  static Color generateVibrantColor(String text) {
    return HSVColor.fromAHSV(1.0, (text.hashCode % 360).toDouble(), 0.8, 0.95).toColor();
  }
}