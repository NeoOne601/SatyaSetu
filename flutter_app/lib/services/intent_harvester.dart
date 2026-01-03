/**
 * FILE: flutter_app/lib/services/intent_harvester.dart
 * VERSION: 2.0.0
 * PHASE: Phase 52.1 (Cryptographic Intent Ledger)
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Harvests interactions and signs them with the user's DID 
 * from the Identity Repository. Implements the "Physical Knowledge Graph" anchor.
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
  final int satyaTrustScore; // 1-10 rating of the AI's helpfulness
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

  /// RECORDS AND SIGNS: The physical interaction pulse.
  static Future<void> harvest(
    IdentityRepository repo, 
    String label, 
    SituationContext context, 
    String actionLabel, 
    int score
  ) async {
    // 1. Obtain current identity
    final identities = await repo.getIdentities();
    if (identities.isEmpty) return;
    final did = identities.first.id;

    // 2. Prepare Payload for signing
    final payload = "$label|$actionLabel|${DateTime.now().toIso8601String()}";
    
    // 3. Cryptographically Sign the Intent (using our Rust Core)
    final signature = await repo.signIntent(did, payload);

    final pulse = IntentPulse(
      label: label,
      context: context,
      actionLabel: actionLabel,
      signerDID: did,
      signature: signature,
      satyaTrustScore: score,
      timestamp: DateTime.now(),
    );

    _harvestBuffer.add(pulse);
    
    // MISSION CONTROL: Log the signed pulse for indexing
    debugPrint("flutter: SATYA_DEBUG: [LEDGER] Signed Pulse Recorded: ${jsonEncode(pulse.toJson())}");
  }

  static List<IntentPulse> get pulses => List.unmodifiable(_harvestBuffer);
}