/**
 * FILE: flutter_app/lib/services/discovery_service.dart
 * VERSION: 1.0.0
 * PHASE: Phase 10.2 (Passive Discovery)
 * DESCRIPTION: Manages the BLE "Radar" pulse to detect nearby trusted nodes.
 * NOTE: Includes simulation mode for testing.
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class DiscoveryNode {
  final String id;
  final String didFragment;
  final double karmaScore;
  final String sector; // "transport", "trade", "civic"
  final double rssi; // Signal strength (-100 to 0)
  final DateTime lastSeen;

  DiscoveryNode({
    required this.id,
    required this.didFragment,
    required this.karmaScore,
    required this.sector,
    required this.rssi,
    required this.lastSeen,
  });
}

class DiscoveryService {
  final _nodeController = StreamController<List<DiscoveryNode>>.broadcast();
  Stream<List<DiscoveryNode>> get radarPulse => _nodeController.stream;

  bool _isScanning = false;
  Timer? _simulationTimer;

  // Real BLE implementation would use flutter_blue_plus here
  
  void activateRadar() {
    if (_isScanning) return;
    _isScanning = true;
    debugPrint("SATYA_RADAR: Background Passive Discovery Active.");
    _startSimulationPulse();
  }

  void deactivateRadar() {
    _isScanning = false;
    _simulationTimer?.cancel();
    debugPrint("SATYA_RADAR: Radar Deactivated.");
  }

  void _startSimulationPulse() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isScanning) return;

      final random = Random();
      
      final List<DiscoveryNode> nodes = [];
      int count = random.nextInt(3) + 1;

      for (int i = 0; i < count; i++) {
        nodes.add(DiscoveryNode(
          id: "node_${random.nextInt(1000)}",
          didFragment: "did:satya:...${random.nextInt(9999)}",
          karmaScore: 8.0 + random.nextDouble() * 2.0, 
          sector: random.nextBool() ? "transport" : "trade",
          rssi: -40.0 - random.nextDouble() * 40.0,
          lastSeen: DateTime.now(),
        ));
      }

      _nodeController.add(nodes);
    });
  }
}