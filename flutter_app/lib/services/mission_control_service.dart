/**
 * FILE: flutter_app/lib/services/mission_control_service.dart
 * VERSION: 1.6.0
 * FIX: Added 'totalDetections' and memory-efficient stream handling.
 */

import 'dart:async';
import '../models/telemetry_models.dart';

class MissionControlService {
  static final MissionControlService _instance = MissionControlService._internal();
  factory MissionControlService() => _instance;
  MissionControlService._internal();

  int _cumulative = 0;
  int get totalDetections => _cumulative;

  final _statsController = StreamController<SystemHealth>.broadcast();
  Stream<SystemHealth> get statsStream => _statsController.stream;

  void record(MetricType type, double value) {
    if (type == MetricType.detectionCount) _cumulative += value.toInt();
    
    _statsController.add(SystemHealth(
      averageLatency: 0.0,
      totalDetections: _cumulative,
      errorPercentage: 0.0,
      topIntents: {},
    ));
  }
}