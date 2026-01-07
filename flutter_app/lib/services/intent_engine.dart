/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 5.2.0
 * PHASE: Phase 71.3 (Sovereign Context Logic)
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: 
 * 1. Computes allowed affordances locally using context-aware application logic.
 * 2. Dispatches structured requests to the APE server.
 * 3. Standardized naming for build stability across the project.
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  /// TIER 1: Resolves immediate perception actions locally (0ms latency).
  static SituationState resolveInstant(String label) {
    final String l = label.toUpperCase();
    return SituationState(
      title: "Identity Pulse",
      actions: [
        MorphicAction(
          label: "Visual Truth",
          icon: LucideIcons.eye,
          description: "Florence confirm: $label",
          payloadType: "info",
          onExecute: (c) => {},
        ),
        MorphicAction(
          label: "Ledger Commit",
          icon: LucideIcons.database,
          description: "Record presence in local hub",
          payloadType: "info",
          onExecute: (c) => {},
        ),
      ],
      themeColor: generateVibrantColor(l),
      context: SituationContext.global,
    );
  }

  /// APPLICATION LOGIC: Decides which affordances are valid for the object/context pair.
  static List<String> computeAllowedAffordances(String label, String context) {
    final l = label.toUpperCase();
    if (l.contains("TOMATO") || l.contains("VEGETABLE")) {
      return context == "market" ? ["buy", "inspect_quality", "record_price"] : ["cook", "nutrition", "store"];
    }
    if (l.contains("FACE") || l.contains("PERSON")) {
      return ["verify_identity", "record_encounter", "social_ledger"];
    }
    if (l.contains("PHONE") || l.contains("DEVICE")) {
      return ["inspect", "usage", "record_state"];
    }
    return ["inspect", "record_interaction", "usage", "safety"];
  }

  /// TIER 2: Requests structured action chains from the Gemma APE core.
  static Future<ApeResponse> fetchAffordances(String label, String context) async {
    final allowed = computeAllowedAffordances(label, context);

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/v1/reason"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "object": {"label": label, "confidence": 0.99},
          "context": context,
          "attributes": {},
          "allowed_affordances": allowed
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return ApeResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("APE_HANDSHAKE_STUTTER: $e");
    }
    // Safe Fallback UI trigger
    return ApeResponse(label: label, context: context, affordances: []);
  }

  static Color generateVibrantColor(String text) {
    final int hash = text.hashCode;
    return HSVColor.fromAHSV(1.0, (hash % 360).toDouble(), 0.8, 0.95).toColor();
  }
}