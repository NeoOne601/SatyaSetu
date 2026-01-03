/**
 * FILE: flutter_app/lib/models/telemetry_models.dart
 * VERSION: 1.0.0
 * PHASE: Phase 51.0 (Mission Control Architecture)
 * AUTHOR: SatyaSetu Mission Systems
 * DESCRIPTION: Defines metrics for real-time system observability at scale.
 */

import 'package:flutter/material.dart';

enum MetricType { latency, detectionCount, intentConversion, errorRate }

class SystemPulse {
  final DateTime timestamp;
  final double value;
  final MetricType type;
  final String metadata;

  SystemPulse({
    required this.timestamp,
    required this.value,
    required this.type,
    this.metadata = "",
  });
}

class SystemHealth {
  final double averageLatency;
  final int totalDetections;
  final double errorPercentage;
  final Map<String, int> topIntents;

  SystemHealth({
    required this.averageLatency,
    required this.totalDetections,
    required this.errorPercentage,
    required this.topIntents,
  });
}