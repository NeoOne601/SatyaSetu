/**
 * FILE: flutter_app/lib/models/intent_models.dart
 * VERSION: 8.0.0
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: Data Schema for Interaction Lifecycle.
 * - APE Response models for affordances
 * - ActivitySession for tracking complete interaction flow
 * - StepCompletion for step-by-step progress
 */

import 'package:flutter/material.dart';

enum SituationContext { global, market, home, office }

class SituationState {
  final String title;
  final SituationContext context;
  final List<MorphicAction> actions;
  final Color themeColor;

  SituationState({required this.title, required this.context, required this.actions, required this.themeColor});
}

class MorphicAction {
  final String label;
  final IconData icon;
  final String description;
  final String payloadType;
  final Function(BuildContext) onExecute;

  MorphicAction({required this.label, required this.icon, required this.description, required this.payloadType, required this.onExecute});
}

class ApeResponse {
  final String label;
  final String context;
  final List<ApeAffordance> affordances;

  ApeResponse({required this.label, required this.context, required this.affordances});

  factory ApeResponse.fromJson(Map<String, dynamic> json) {
    var affList = json['affordances'] as List? ?? [];
    return ApeResponse(
      label: json['object']?['label'] ?? json['label'] ?? "unknown",
      context: json['context'] ?? "general",
      affordances: affList.map((i) => ApeAffordance.fromJson(i)).toList(),
    );
  }

  static ApeResponse empty({String label = "unknown", String context = "general"}) => 
      ApeResponse(label: label, context: context, affordances: []);
}

class ApeAffordance {
  final String name;
  final double confidence;
  final List<ApeAction> actions;

  ApeAffordance({required this.name, required this.confidence, required this.actions});

  factory ApeAffordance.fromJson(Map<String, dynamic> json) {
    var actList = json['actions'] as List? ?? [];
    return ApeAffordance(
      name: json['name'] ?? "Action Group",
      confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
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
      step: json['step'] ?? 0,
      instruction: json['instruction'] ?? "Follow standard protocol",
      recordable: json['recordable'] ?? false,
    );
  }
}

// ============================================================================
// INTERACTION LIFECYCLE MODELS
// ============================================================================

/// Tracks completion of a single step in an affordance chain
class StepCompletion {
  final String affordanceName;
  final int stepIndex;
  final DateTime completedAt;
  final String? note;

  StepCompletion({
    required this.affordanceName,
    required this.stepIndex,
    required this.completedAt,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'affordance': affordanceName,
    'step': stepIndex,
    'completedAt': completedAt.toIso8601String(),
    'note': note,
  };
}

/// Tracks a complete interaction session from object detection to rating
class ActivitySession {
  final String objectLabel;
  final String category;
  final ApeResponse affordanceResponse;
  final List<StepCompletion> completedSteps;
  final DateTime startTime;
  DateTime? endTime;
  int? userRating; // 1-5 stars
  String? userNote;
  bool isCompleted;

  ActivitySession({
    required this.objectLabel,
    required this.category,
    required this.affordanceResponse,
    List<StepCompletion>? completedSteps,
    DateTime? startTime,
    this.endTime,
    this.userRating,
    this.userNote,
    this.isCompleted = false,
  }) : completedSteps = completedSteps ?? [],
       startTime = startTime ?? DateTime.now();

  /// Mark a step as completed
  void completeStep(String affordanceName, int stepIndex, {String? note}) {
    completedSteps.add(StepCompletion(
      affordanceName: affordanceName,
      stepIndex: stepIndex,
      completedAt: DateTime.now(),
      note: note,
    ));
  }

  /// Check if a specific step is completed
  bool isStepCompleted(String affordanceName, int stepIndex) {
    return completedSteps.any((s) => s.affordanceName == affordanceName && s.stepIndex == stepIndex);
  }

  /// Get total number of steps across all affordances
  int get totalSteps => affordanceResponse.affordances.fold(0, (sum, a) => sum + a.actions.length);

  /// Get number of completed steps
  int get completedStepCount => completedSteps.length;

  /// Get completion percentage
  double get completionPercentage => totalSteps > 0 ? completedStepCount / totalSteps : 0.0;

  /// Finalize the session with rating
  void finalize(int rating, {String? note}) {
    userRating = rating;
    userNote = note;
    endTime = DateTime.now();
    isCompleted = true;
  }

  /// Convert to JSON for DID storage
  Map<String, dynamic> toJson() => {
    'objectLabel': objectLabel,
    'category': category,
    'affordances': affordanceResponse.affordances.map((a) => a.name).toList(),
    'completedSteps': completedSteps.map((s) => s.toJson()).toList(),
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'rating': userRating,
    'note': userNote,
    'completionPercentage': completionPercentage,
  };
}