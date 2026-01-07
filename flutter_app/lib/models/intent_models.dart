/**
 * FILE: flutter_app/lib/models/intent_models.dart
 * VERSION: 6.0.0
 * PHASE: Phase 71.2 (APE Schema Support)
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: 
 * 1. Added ApeResponse, ApeAffordance, and ApeAction for structured JSON parsing.
 * 2. Maintained legacy SituationState and MorphicAction for UI consistency.
 */

import 'package:flutter/material.dart';

enum SituationContext { global, market, home, office }

class SituationState {
  final String title;
  final SituationContext context;
  final List<MorphicAction> actions;
  final Color themeColor;

  SituationState({
    required this.title,
    required this.context,
    required this.actions,
    required this.themeColor,
  });
}

class MorphicAction {
  final String label;
  final IconData icon;
  final String description;
  final String payloadType;
  final Function(BuildContext) onExecute;

  MorphicAction({
    required this.label,
    required this.icon,
    required this.description,
    required this.payloadType,
    required this.onExecute,
  });
}

/// APE Response: The root container for structured affordance plans.
class ApeResponse {
  final String label;
  final String context;
  final List<ApeAffordance> affordances;

  ApeResponse({required this.label, required this.context, required this.affordances});

  factory ApeResponse.fromJson(Map<String, dynamic> json) {
    var affList = json['affordances'] as List? ?? [];
    return ApeResponse(
      label: json['object']?['label'] ?? "unknown",
      context: json['context'] ?? "unknown",
      affordances: affList.map((i) => ApeAffordance.fromJson(i)).toList(),
    );
  }
}

class ApeAffordance {
  final String name;
  final double confidence;
  final List<ApeAction> actions;

  ApeAffordance({required this.name, required this.confidence, required this.actions});

  factory ApeAffordance.fromJson(Map<String, dynamic> json) {
    var actList = json['actions'] as List? ?? [];
    return ApeAffordance(
      name: json['name'],
      confidence: (json['confidence'] as num).toDouble(),
      actions: actList.map((i) => ApeAction.fromJson(i)).toList(),
    );
  }
}

class ApeAction {
  final int step;
  final String instruction;
  final bool recordable;

  ApeAction({required this.step, required this.instruction, required this.recordable});

  factory ApeAction.fromJson(Map<String, dynamic> json) {
    return ApeAction(
      step: json['step'],
      instruction: json['instruction'],
      recordable: json['recordable'],
    );
  }
}