/**
 * FILE: flutter_app/lib/services/mission_control_service.dart
 * VERSION: 1.2.0
 * PHASE: Phase 61.0 (Synchronous Observability)
 * AUTHOR: SatyaSetu Mission Systems
 * FIX: Added synchronous 'totalDetections' getter to resolve UI build error.
 */

import 'dart:async';
import '../models/telemetry_models.dart';

class MissionControlService {
  static final MissionControlService _instance = MissionControlService._internal();
  factory MissionControlService() => _instance;
  MissionControlService._internal();

  final List<SystemPulse> _pulseBuffer = [];
  final _statsStreamController = StreamController<SystemHealth>.broadcast();
  
  // FIX: Explicit tracking for synchronous UI status checks
  int _detectionCount = 0;
  int get totalDetections => _detectionCount;

  Stream<SystemHealth> get statsStream => _statsStreamController.stream;

  void record(MetricType type, double value, {String metadata = ""}) {
    if (type == MetricType.detectionCount) {
      _detectionCount += value.toInt();
    }

    final pulse = SystemPulse(
      timestamp: DateTime.now(),
      value: value,
      type: type,
      metadata: metadata,
    );

    _pulseBuffer.add(pulse);
    if (_pulseBuffer.length > 500) _pulseBuffer.removeAt(0);

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
      totalDetections: _detectionCount,
      errorPercentage: errors.length / _pulseBuffer.length * 100,
      topIntents: {},
    ));
  }
}