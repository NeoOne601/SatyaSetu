/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 4.2.0
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Implements the "APE" (Affordance Planning Engine).
 * Florence actions are hardcoded here for 0ms latency.
 * Gemma actions are fetched asynchronously.
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  /// AFFORDANCE PLANNING ENGINE: Maps detection labels to instant action choices.
  static SituationState resolveInstant(String label) {
    final String l = label.toUpperCase();
    final Color color = generateVibrantColor(l);
    
    // TIER 1: THE FLORENCE AFFORDANCES (Instant choices based on label mapping)
    List<MorphicAction> choices = [
      MorphicAction(
        label: "Visual Audit", 
        icon: LucideIcons.eye, 
        description: "Verified presence of $label",
        payloadType: "info",
        onExecute: (c) => {}
      ),
      MorphicAction(
        label: "Ledger Record", 
        icon: LucideIcons.database, 
        description: "Cryptographic index of $label",
        payloadType: "info",
        onExecute: (c) => {}
      ),
    ];

    // INGENIOUS: Semantic Override (We can add custom mappings here for specific objects)
    if (l.contains("TOMATO") || l.contains("VEGETABLE")) {
      choices[1] = MorphicAction(
        label: "Market Price Check", 
        icon: LucideIcons.indianRupee, 
        description: "Fetch local Mandi index",
        payloadType: "info",
        onExecute: (c) => {}
      );
    }

    return SituationState(title: "Perception Tier", actions: choices, themeColor: color, context: SituationContext.global);
  }

  /// TIER 2: THE GEMMA INQUIRIES (Deep reasoning)
  static Future<List<String>> fetchInquiries(String label) async {
    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/v1/reason"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"object": label})
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['questions']);
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [APE] Inquiry fallback triggered.");
    }
    return ["Properties of $label?", "Origin of $label?", "Value of $label?"];
  }

  static Color generateVibrantColor(String text) {
    return HSVColor.fromAHSV(1.0, (text.hashCode % 360).toDouble(), 0.8, 0.95).toColor();
  }
}