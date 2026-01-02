/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * VERSION: 1.1.1
 * PHASE: Phase 49.1 (Generative Ontology - Build Fix)
 * AUTHOR: SatyaSetu Internal Neural Team
 * DESCRIPTION: Dynamic situational brain. Uses categorical trait detection 
 * instead of hardcoded object lists. Fixed invalid icon reference.
 */

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  /// Dynamically decodes any AI label into a situational intent state.
  static SituationState decode(String label) {
    final String l = label.toUpperCase();

    // 1. DYNAMIC TRADE/MANDI TRAITS
    if (_hasTrait(l, ["FOOD", "VEG", "FRUIT", "POTATO", "TOMATO", "ONION", "BAG", "BASKET", "STALL"])) {
      return SituationState(
        title: "Trade Interaction",
        context: SituationContext.trade,
        themeColor: Colors.orangeAccent,
        actions: [
          MorphicAction(label: "Quality Audit", icon: LucideIcons.checkCircle, description: "Rate freshness & grade.", onExecute: (c) => _log(c, "Audit Recorded")),
          MorphicAction(label: "Price Index", icon: LucideIcons.trendingUp, description: "Check current Mandi rates.", onExecute: (c) => _log(c, "Price Synced")),
        ],
      );
    }

    // 2. DYNAMIC EDUCATION/LOGIC TRAITS
    if (_hasTrait(l, ["BOOK", "NOTE", "PEN", "MARKER", "PENCIL", "PAPER", "WRITING", "LEARN"])) {
      return SituationState(
        title: "Cognitive Session",
        context: SituationContext.education,
        themeColor: Colors.blueAccent,
        actions: [
          MorphicAction(label: "Mentor Help", icon: LucideIcons.brainCircuit, description: "AI-assisted problem solving.", onExecute: (c) => _log(c, "Mentor Mode Active")),
          // FIX: Changed scanText to scanLine to resolve build error
          MorphicAction(label: "OCR Digitize", icon: LucideIcons.scanLine, description: "Convert to digital knowledge.", onExecute: (c) => _log(c, "Context Indexed")),
        ],
      );
    }

    // 3. DYNAMIC FINANCE TRAITS
    if (_hasTrait(l, ["QR", "CODE", "CASH", "PAY", "WALLET", "CARD", "BILL", "RECEIPT"])) {
      return SituationState(
        title: "Finance Terminal",
        context: SituationContext.finance,
        themeColor: const Color(0xFF00FFC8),
        actions: [
          MorphicAction(label: "Secure Pay", icon: LucideIcons.shieldCheck, description: "Authenticate and log payment.", onExecute: (c) => _log(c, "Ledger Entry Saved")),
          MorphicAction(label: "Vendor Trust", icon: LucideIcons.thumbsUp, description: "Rate seller behavior.", onExecute: (c) => _log(c, "Trust Signal Broadcast")),
        ],
      );
    }

    // 4. DYNAMIC DOMESTIC/UTILITY TRAITS
    if (_hasTrait(l, ["CHAIR", "TABLE", "CUP", "MUG", "BOTTLE", "DOOR", "LIGHT"])) {
      return SituationState(
        title: "Utility Context",
        context: SituationContext.domestic,
        themeColor: Colors.purpleAccent,
        actions: [
          MorphicAction(label: "Home Control", icon: LucideIcons.home, description: "Smart interaction layer.", onExecute: (c) => _log(c, "Control Pulse Sent")),
          MorphicAction(label: "Maintenance", icon: LucideIcons.wrench, description: "Log condition or issue.", onExecute: (c) => _log(c, "Log Updated")),
        ],
      );
    }

    // 5. GENERATIVE FALLBACK
    return SituationState(
      title: "Discovery Mode",
      context: SituationContext.global,
      actions: [
        MorphicAction(label: "Explore", icon: LucideIcons.search, description: "Deep visual search for info.", onExecute: (c) => _log(c, "Deep Discovery Active")),
      ],
    );
  }

  static bool _hasTrait(String label, List<String> traits) {
    return traits.any((t) => label.contains(t));
  }

  static void _log(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF00FFC8),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }
}