/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 2.1.0
 * PHASE: Phase 52.3 (Spectral Semantics)
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Assigns dynamic hex colors and situational intents on the fly.
 * No hardcoded color lists; the AI selects the color based on object category.
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  static const String _apiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent";
  static const String _apiKey = ""; // Injected by environment

  /// ASYNC RESOLVER: Predicts situation, actions, and dynamic category color.
  static Future<SituationState> resolve(String label, List<String> environmentalContext) async {
    try {
      final prompt = """
      Act as the SatyaSetu Spectral Reasoning Engine.
      Subject: '$label' 
      Surroundings: ${environmentalContext.join(", ")}
      
      1. Determine the category (Trade, Education, Finance, Domestic, Global).
      2. Choose a representative HEX color (e.g., #FF9F1C for food, #2EC4B6 for tech, #E71D36 for living).
      3. Suggest 2 relevant actions.
      
      Return ONLY valid JSON:
      {
        "context": "mandi", 
        "title": "Produce Interaction", 
        "hex": "#FF9F1C",
        "actions": [
          {"label": "Quality Audit", "icon": "checkCircle", "desc": "Rate freshness"},
          {"label": "Price Index", "icon": "trendingUp", "desc": "Check market rate"}
        ]
      }
      """;

      final response = await http.post(
        Uri.parse("$_apiEndpoint?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}],
          "generationConfig": {"responseMimeType": "application/json"}
        })
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final jsonText = data['candidates'][0]['content']['parts'][0]['text'];
        final Map<String, dynamic> result = jsonDecode(jsonText);

        return _buildFromAI(result);
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [REASONER] Connection Stutter: $e");
    }

    return SituationState(
      title: "Observing...",
      context: SituationContext.global,
      actions: [],
    );
  }

  static SituationState _buildFromAI(Map<String, dynamic> json) {
    return SituationState(
      title: json['title'],
      context: SituationContext.values.firstWhere(
        (e) => e.toString().contains(json['context']), 
        orElse: () => SituationContext.global
      ),
      themeColor: _colorFromHex(json['hex']),
      actions: (json['actions'] as List).map((a) => MorphicAction(
        label: a['label'],
        icon: _mapIcon(a['icon']),
        description: a['desc'],
        onExecute: (ctx) => {}, 
      )).toList(),
    );
  }

  static Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static IconData _mapIcon(String name) {
    if (name == "checkCircle") return LucideIcons.checkCircle;
    if (name == "trendingUp") return LucideIcons.trendingUp;
    if (name == "brainCircuit") return LucideIcons.brainCircuit;
    return LucideIcons.zap;
  }
}