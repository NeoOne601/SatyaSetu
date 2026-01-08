/**
 * FILE: flutter_app/lib/services/intent_harvester.dart
 * VERSION: 3.0.0
 * PHASE: Interaction Lifecycle
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Harvests interaction sessions and individual intents.
 * - Session harvesting for complete activity flows
 * - Trust score accumulation
 * - DID-signed ledger entries
 */

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/intent_models.dart';
import '../identity_repo.dart';

class IntentPulse {
  final String label;
  final SituationContext context;
  final String actionLabel;
  final String signerDID;
  final String signature;
  final int satyaTrustScore;
  final DateTime timestamp;

  IntentPulse({
    required this.label,
    required this.context,
    required this.actionLabel,
    required this.signerDID,
    required this.signature,
    required this.satyaTrustScore,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'context': context.toString(),
    'action': actionLabel,
    'did': signerDID,
    'sig': signature,
    'score': satyaTrustScore,
    'ts': timestamp.toIso8601String(),
  };
}

/// Session pulse captures a complete interaction session
class SessionPulse {
  final String objectLabel;
  final String category;
  final List<String> affordancesUsed;
  final int stepsCompleted;
  final int totalSteps;
  final int userRating;
  final String? userNote;
  final String signerDID;
  final String signature;
  final DateTime startTime;
  final DateTime endTime;

  SessionPulse({
    required this.objectLabel,
    required this.category,
    required this.affordancesUsed,
    required this.stepsCompleted,
    required this.totalSteps,
    required this.userRating,
    this.userNote,
    required this.signerDID,
    required this.signature,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'object': objectLabel,
    'category': category,
    'affordances': affordancesUsed,
    'progress': '$stepsCompleted/$totalSteps',
    'rating': userRating,
    'note': userNote,
    'did': signerDID,
    'sig': signature,
    'start': startTime.toIso8601String(),
    'end': endTime.toIso8601String(),
  };
  
  /// Calculate trust contribution (higher rating + more steps = more trust)
  int get trustContribution => ((userRating * 10) + (stepsCompleted * 5)).clamp(0, 100);
}

class IntentHarvester {
  static final List<IntentPulse> _harvestBuffer = [];
  static final List<SessionPulse> _sessionBuffer = [];
  static int _accumulatedTrustScore = 0;

  /// Harvest a single intent (legacy support)
  static Future<void> harvest(
    IdentityRepository repo, 
    String label, 
    SituationContext context, 
    String actionLabel, 
    int score
  ) async {
    final identities = await repo.getIdentities();
    if (identities.isEmpty) return;
    final did = identities.first.id;

    final payload = "$label|$actionLabel|${DateTime.now().toIso8601String()}";
    String finalSignature = "unsigned_intent";

    try {
      finalSignature = await repo.signIntent(did, payload);
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [HARVESTER] Signature skipped: $e");
      finalSignature = "H-INT-${payload.hashCode}";
    }

    final pulse = IntentPulse(
      label: label,
      context: context,
      actionLabel: actionLabel,
      signerDID: did,
      signature: finalSignature,
      satyaTrustScore: score,
      timestamp: DateTime.now(),
    );

    _harvestBuffer.add(pulse);
    _accumulatedTrustScore += score;
    debugPrint("flutter: SATYA_DEBUG: [LEDGER] Intent: ${jsonEncode(pulse.toJson())}");
  }

  /// Harvest a complete activity session
  static Future<SessionPulse?> harvestSession(
    IdentityRepository repo,
    ActivitySession session,
  ) async {
    if (!session.isCompleted || session.userRating == null) {
      debugPrint("flutter: SATYA_DEBUG: [HARVESTER] Session not ready for harvest");
      return null;
    }

    final identities = await repo.getIdentities();
    if (identities.isEmpty) return null;
    final did = identities.first.id;

    // Create payload for signing
    final affordanceNames = session.affordanceResponse.affordances.map((a) => a.name).toList();
    final payload = "${session.objectLabel}|${session.category}|${session.userRating}|${session.startTime.toIso8601String()}";
    
    String finalSignature = "unsigned_session";
    try {
      finalSignature = await repo.signIntent(did, payload);
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [HARVESTER] Session signature skipped: $e");
      finalSignature = "H-SESS-${payload.hashCode}";
    }

    final sessionPulse = SessionPulse(
      objectLabel: session.objectLabel,
      category: session.category,
      affordancesUsed: affordanceNames,
      stepsCompleted: session.completedStepCount,
      totalSteps: session.totalSteps,
      userRating: session.userRating!,
      userNote: session.userNote,
      signerDID: did,
      signature: finalSignature,
      startTime: session.startTime,
      endTime: session.endTime ?? DateTime.now(),
    );

    _sessionBuffer.add(sessionPulse);
    _accumulatedTrustScore += sessionPulse.trustContribution;
    
    debugPrint("flutter: SATYA_DEBUG: [LEDGER] Session: ${jsonEncode(sessionPulse.toJson())}");
    debugPrint("flutter: SATYA_DEBUG: [TRUST] +${sessionPulse.trustContribution} → Total: $_accumulatedTrustScore");
    
    return sessionPulse;
  }

  /// Get all harvested intents
  static List<IntentPulse> get pulses => List.unmodifiable(_harvestBuffer);
  
  /// Get all harvested sessions
  static List<SessionPulse> get sessions => List.unmodifiable(_sessionBuffer);
  
  /// Get accumulated trust score
  static int get trustScore => _accumulatedTrustScore;
  
  /// Get stats
  static Map<String, dynamic> get stats => {
    'totalIntents': _harvestBuffer.length,
    'totalSessions': _sessionBuffer.length,
    'trustScore': _accumulatedTrustScore,
  };
}