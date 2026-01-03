/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 2.7.0
 * PHASE: Phase 57.0 (General Intelligence Loop)
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Handles both local heuristic schemas and deep cloud reasoning.
 * Implements the "Ask Mentor" logic to provide actual answers to user questions.
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  static const String _apiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent";
  static const String _apiKey = ""; // Injected by env

  /// DYNAMIC SCHEMER: Decides what actions to show for any object.
  static Future<SituationState> resolve(String label, String sceneContext, List<String> objects) async {
    final String l = label.toUpperCase();
    final Color dynamicColor = _generateVibrantColor(l);

    // Instead of hardcoding, we use 'Scene Context' from Florence to guess the schema
    String title = "Object Identified";
    List<Map<String, String>> actions = [
      {"label": "Ask Mentor", "type": "input", "desc": "Question about $label"},
      {"label": "Quick Audit", "type": "rate", "desc": "Log $label state"}
    ];

    if (sceneContext.contains("market") || sceneContext.contains("shop")) {
      title = "Commercial Context";
      actions.add({"label": "Price Index", "type": "input", "desc": "Log local rate"});
    } else if (sceneContext.contains("kitchen") || sceneContext.contains("cooking")) {
      title = "Domestic Context";
      actions.add({"label": "Nutrition", "type": "info", "desc": "Check health data"});
    }

    return _buildMorphicState(title, dynamicColor, actions);
  }

  /// THE BRAIN PULSE: Actually answers the "Ask Mentor" question.
  static Future<String> askMentor(String object, String question, String context) async {
    try {
      final prompt = "You are SatyaSetu Mentor. User is looking at '$object' in a '$context'. They ask: '$question'. Provide a concise, intelligent answer (max 2 sentences).";
      
      final response = await http.post(
        Uri.parse("$_apiEndpoint?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}],
        })
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      }
    } catch (e) {
      return "Mentor link stuttered. Please try again.";
    }
    return "Searching knowledge graph...";
  }

  static SituationState _buildMorphicState(String title, Color color, List<Map<String, String>> actions) {
    return SituationState(
      title: title,
      context: SituationContext.global,
      themeColor: color,
      actions: actions.map((a) => MorphicAction(
        label: a['label']!,
        icon: a['type'] == "input" ? LucideIcons.messageSquare : (a['type'] == "rate" ? LucideIcons.star : LucideIcons.info),
        description: a['desc']!,
        payloadType: a['type']!,
        onExecute: (c) => {},
      )).toList(),
    );
  }

  static Color _generateVibrantColor(String text) {
    final int hash = text.hashCode;
    return HSVColor.fromAHSV(1.0, (hash % 360).toDouble(), 0.8, 0.9).toColor();
  }
}