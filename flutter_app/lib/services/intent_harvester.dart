/**
 * FILE: flutter_app/lib/services/intent_harvester.dart
 * VERSION: 2.1.0
 * PHASE: Phase 54.0 (Signature Resilience)
 * AUTHOR: SatyaSetu Neural Architect
 * FIX: Added try-catch guard for the Rust bridge to prevent UPI validation 
 * crashes during generic physical interactions (Mandi/Education).
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

class IntentHarvester {
  static final List<IntentPulse> _harvestBuffer = [];

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
    String finalSignature = "unsigned_intent_metadata";

    try {
      // ATTEMPT CRYPTOGRAPHIC SIGNING
      // Note: Rust core currently validates for 'upi://' prefix. 
      // If validation fails, we catch the exception to keep the app running.
      finalSignature = await repo.signIntent(did, payload);
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [HARVESTER] Signature skipped (Non-UPI data): $e");
      // Fallback: Generate a deterministic hash for tracking without crashing
      finalSignature = "H-INTENT-${payload.hashCode}";
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
    debugPrint("flutter: SATYA_DEBUG: [LEDGER] Pulse Harvested: ${jsonEncode(pulse.toJson())}");
  }

  static List<IntentPulse> get pulses => List.unmodifiable(_harvestBuffer);
}