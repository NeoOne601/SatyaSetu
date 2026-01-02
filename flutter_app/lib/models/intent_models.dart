/**
 * FILE: flutter_app/lib/models/intent_models.dart
 * VERSION: 1.1.0
 * PHASE: Phase 49.0 (Ontological Intent)
 * AUTHOR: SatyaSetu Internal Neural Team
 * DESCRIPTION: Data models for dynamic situational morphing.
 */

import 'package:flutter/material.dart';

enum SituationContext { global, trade, education, finance, domestic, logistics }

class MorphicAction {
  final String label;
  final IconData icon;
  final String description;
  final Function(BuildContext context) onExecute;

  MorphicAction({
    required this.label,
    required this.icon,
    required this.description,
    required this.onExecute,
  });
}

class SituationState {
  final String title;
  final SituationContext context;
  final List<MorphicAction> actions;
  final Color themeColor;

  SituationState({
    required this.title,
    required this.context,
    required this.actions,
    this.themeColor = const Color(0xFF00FFC8),
  });
}