/**
 * FILE: flutter_app/lib/models/intent_models.dart
 * VERSION: 1.2.0
 * PHASE: Phase 55.1 (Action Payloads)
 * AUTHOR: SatyaSetu Mission Systems
 */

import 'package:flutter/material.dart';

enum SituationContext { global, trade, education, finance, domestic }

class MorphicAction {
  final String label;
  final IconData icon;
  final String description;
  final String payloadType; // NEW: Tells UI what kind of interaction to show (input/rate/info)
  final Function(BuildContext context) onExecute;

  MorphicAction({
    required this.label,
    required this.icon,
    required this.description,
    required this.payloadType,
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