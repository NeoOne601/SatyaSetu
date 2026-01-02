/**
 * FILE: flutter_app/lib/services/intent_engine.dart
 * PURPOSE: Decoupled logic to map raw AI detections to Human Intent.
 */

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/intent_models.dart';

class IntentEngine {
  /// Decodes the semantic label from Florence-2 into a SituationState.
  static SituationState decode(String label) {
    final String l = label.toUpperCase();

    // 1. MANDI CONTEXT (Trade & Quality)
    if (l.contains("POTATO") || l.contains("TOMATO") || l.contains("VEGETABLE") || l.contains("FRUIT")) {
      return SituationState(
        title: "Produce Interaction",
        context: SituationContext.mandi,
        themeColor: Colors.orangeAccent,
        actions: [
          MorphicAction(
            label: "Rate Quality", 
            icon: LucideIcons.star, 
            description: "Record freshness and grade.",
            onExecute: (ctx) => _logAction(ctx, "Quality Rated")
          ),
          MorphicAction(
            label: "Track Price", 
            icon: LucideIcons.trendingUp, 
            description: "Compare with local market average.",
            onExecute: (ctx) => _logAction(ctx, "Price Indexed")
          ),
        ],
      );
    }

    // 2. EDUCATION CONTEXT (Mentor Mode)
    if (l.contains("NOTEBOOK") || l.contains("BOOK") || l.contains("PEN") || l.contains("WRITING")) {
      return SituationState(
        title: "Learning Session",
        context: SituationContext.education,
        themeColor: Colors.blueAccent,
        actions: [
          MorphicAction(
            label: "Solve Problem", 
            icon: LucideIcons.brainCircuit, 
            description: "AI-assisted homework help.",
            onExecute: (ctx) => _logAction(ctx, "Mentorship Active")
          ),
          MorphicAction(
            label: "Scan Content", 
            icon: LucideIcons.scanLine, 
            description: "Digitize and summarize notes.",
            onExecute: (ctx) => _logAction(ctx, "Notes Digitized")
          ),
        ],
      );
    }

    // 3. FINANCE CONTEXT (Transaction Guard)
    if (l.contains("QR") || l.contains("CASH") || l.contains("WALLET") || l.contains("PAYMENT")) {
      return SituationState(
        title: "Financial Event",
        context: SituationContext.finance,
        themeColor: const Color(0xFF00FFC8),
        actions: [
          MorphicAction(
            label: "Record Amount", 
            icon: LucideIcons.indianRupee, 
            description: "Store transaction in private ledger.",
            onExecute: (ctx) => _logAction(ctx, "Ledger Updated")
          ),
          MorphicAction(
            label: "Rate Seller", 
            icon: LucideIcons.thumbsUp, 
            description: "Review behavior and trust level.",
            onExecute: (ctx) => _logAction(ctx, "Vendor Rated")
          ),
        ],
      );
    }

    // DEFAULT
    return SituationState(
      title: "Observed Object",
      context: SituationContext.global,
      actions: [
        MorphicAction(
          label: "View Info", 
          icon: LucideIcons.info, 
          description: "General knowledge lookup.",
          onExecute: (ctx) => _logAction(ctx, "Lookup executed")
        ),
      ],
    );
  }

  static void _logAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF00FFC8), duration: const Duration(seconds: 1))
    );
  }
}