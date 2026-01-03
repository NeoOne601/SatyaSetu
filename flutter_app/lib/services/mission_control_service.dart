/**
 * FILE: flutter_app/lib/services/mission_control_service.dart
 * VERSION: 1.0.0
 * PHASE: Phase 51.1 (Observability Pipeline)
 * AUTHOR: SatyaSetu Mission Systems
 * DESCRIPTION: Handles high-volume telemetry gathering. Implements a 
 * circular buffer to prevent memory bloat at billion-user scale.
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/telemetry_models.dart';

class MissionControlService {
  static final MissionControlService _instance = MissionControlService._internal();
  factory MissionControlService() => _instance;
  MissionControlService._internal();

  final List<SystemPulse> _pulseBuffer = [];
  final _statsStreamController = StreamController<SystemHealth>.broadcast();

  Stream<SystemHealth> get statsStream => _statsStreamController.stream;

  /// Records a telemetry event (The "Black Box" recorder)
  void record(MetricType type, double value, {String metadata = ""}) {
    final pulse = SystemPulse(
      timestamp: DateTime.now(),
      value: value,
      type: type,
      metadata: metadata,
    );

    _pulseBuffer.add(pulse);
    
    // SCALE GUARD: Maintain only the last 500 pulses in memory (Circular Buffer)
    if (_pulseBuffer.length > 500) {
      _pulseBuffer.removeAt(0);
    }

    _calculateAndEmit();
  }

  void _calculateAndEmit() {
    if (_pulseBuffer.isEmpty) return;

    final latencies = _pulseBuffer.where((p) => p.type == MetricType.latency);
    final errors = _pulseBuffer.where((p) => p.type == MetricType.errorRate);
    
    final avgLat = latencies.isNotEmpty 
        ? latencies.map((e) => e.value).reduce((a, b) => a + b) / latencies.length 
        : 0.0;

    _statsStreamController.add(SystemHealth(
      averageLatency: avgLat,
      totalDetections: _pulseBuffer.where((p) => p.type == MetricType.detectionCount).length,
      errorPercentage: errors.length / _pulseBuffer.length * 100,
      topIntents: {}, // Future: Aggregate from metadata
    ));
  }
}