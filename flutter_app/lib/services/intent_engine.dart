/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 2.3.0
 * PHASE: Phase 54.1 (Spectral Chromatic Balancing)
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Hybrid reasoning engine with enhanced color hashing.
 * Ensures that AI-generated colors are always visible and distinct.
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  static const String _apiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent";
  static const String _apiKey = ""; 

  static Future<SituationState> resolve(String label, List<String> context) async {
    final String l = label.toUpperCase();
    
    // SPECTRAL COLORING: High-contrast deterministic hashing
    final Color dynamicColor = _generateVibrantColor(l);

    // FAST-PATH LOCAL ONTOLOGY
    if (_hasTrait(l, ["FOOD", "VEG", "FRUIT", "TOMATO", "POTATO", "BASKET", "MARKET"])) {
      return _buildMandi(label, dynamicColor);
    }
    
    if (_hasTrait(l, ["BOOK", "NOTE", "PEN", "PAPER", "LEARN", "WRITING"])) {
      return _buildEdu(label, dynamicColor);
    }

    if (_hasTrait(l, ["QR", "CODE", "CASH", "PAY", "WALLET", "BILL"])) {
      return _buildFinance(label, dynamicColor);
    }

    // GENERAL INTELLIGENCE FALLBACK (The Gemini Brain)
    return await _queryCloud(label, context, dynamicColor);
  }

  static bool _hasTrait(String label, List<String> traits) {
    return traits.any((t) => label.contains(t));
  }

  /// NEW: Vibrant Hash Color. Prevents dark/invisible boxes by forcing high value/saturation.
  static Color _generateVibrantColor(String text) {
    final int hash = text.hashCode;
    final double hue = (hash % 360).toDouble(); // Use hash to pick a hue (0-360)
    // We force saturation to 0.8 and value to 0.9 to ensure "Neon" visibility
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();
  }

  static SituationState _buildMandi(String label, Color color) => SituationState(
    title: "Trade Interaction",
    context: SituationContext.trade,
    themeColor: color,
    actions: [
      MorphicAction(label: "Quality Audit", icon: LucideIcons.star, description: "Grade freshness of $label", onExecute: (c) => {}),
      MorphicAction(label: "Market Price", icon: LucideIcons.trendingUp, description: "Check current Mandi rate", onExecute: (c) => {}),
    ],
  );

  static SituationState _buildEdu(String label, Color color) => SituationState(
    title: "Cognitive Session",
    context: SituationContext.education,
    themeColor: color,
    actions: [
      MorphicAction(label: "Mentor Solve", icon: LucideIcons.brainCircuit, description: "AI problem solving for $label", onExecute: (c) => {}),
      MorphicAction(label: "OCR Digitization", icon: LucideIcons.scanLine, description: "Sync notes to DID vault", onExecute: (c) => {}),
    ],
  );

  static SituationState _buildFinance(String label, Color color) => SituationState(
    title: "Finance Terminal",
    context: SituationContext.finance,
    themeColor: color,
    actions: [
      MorphicAction(label: "Record Pay", icon: LucideIcons.shieldCheck, description: "Log payment amount", onExecute: (c) => {}),
      MorphicAction(label: "Trust Score", icon: LucideIcons.thumbsUp, description: "Rate vendor interaction", onExecute: (c) => {}),
    ],
  );

  static Future<SituationState> _queryCloud(String label, List<String> context, Color color) async {
    try {
      final response = await http.post(
        Uri.parse("$_apiEndpoint?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": "You are SatyaSetu. Context: ${context.join(',')}. Describe 2 intent actions for '$label'. JSON: {'title':str, 'actions':[{'label':str, 'desc':str}]}"}]}],
          "generationConfig": {"responseMimeType": "application/json"}
        })
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<String, dynamic> res = jsonDecode(data['candidates'][0]['content']['parts'][0]['text']);
        return SituationState(
          title: res['title'],
          context: SituationContext.global,
          themeColor: color,
          actions: (res['actions'] as List).map((a) => MorphicAction(
            label: a['label'], icon: LucideIcons.zap, description: a['desc'], onExecute: (c) => {}
          )).toList(),
        );
      }
    } catch (e) { debugPrint("flutter: SATYA_DEBUG: [REASONER] API Offline."); }
    return SituationState(title: "Object Interaction", context: SituationContext.global, themeColor: color, actions: []);
  }
}