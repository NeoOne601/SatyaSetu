/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 81.0.0
 * PHASE: Phase 69.1 (Reactive Pulse Heartbeat)
 * AUTHOR: SatyaSetu Neural Architect
 * FIX: Replaced Timer-based loop with a Sequential Request-Response cycle.
 * This prevents memory ballooning by ensuring only one request is in-flight.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/intent_models.dart';
import '../models/telemetry_models.dart';
import 'mission_control_service.dart';

class DetectionCandidate {
  final String id;
  final String objectLabel;
  final Rect relativeLocation; 
  final bool isLiving;
  DetectionCandidate({required this.id, required this.objectLabel, required this.relativeLocation, required this.isLiving});
}

class VisionService {
  CameraMacOSController? macController; 
  bool _isRunning = false;
  List<DetectionCandidate> _activeRegistry = [];
  String currentScene = "General";
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;

  Future<void> initialize() async {
    debugPrint("flutter: SATYA_DEBUG: [VISION] Reactive Protocol Ready.");
  }

  void attachCamera(CameraMacOSController controller) {
    macController = controller;
    _isRunning = true;
    _startSequentialPulse();
  }

  /// SEQUENTIAL PULSE: Send, Wait, then Schedule Next. 
  /// Prevents memory leaks and request flooding.
  Future<void> _startSequentialPulse() async {
    while (_isRunning) {
      if (macController != null) {
        await _performOnePulse();
      }
      // Brief pause to allow UI thread to breathe
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _performOnePulse() async {
    final stopwatch = Stopwatch()..start();
    try {
      final CameraMacOSFile? rawData = await macController!.takePicture();
      if (rawData?.bytes == null) return;
      
      const url = "http://127.0.0.1:8000/v1/vision"; 
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(rawData!.bytes!)]})
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _activeRegistry = _parseRaw(data['response'] ?? "[]");
        _candidatesController.add(_activeRegistry);
        
        final latency = stopwatch.elapsedMilliseconds;
        debugPrint("flutter: SATYA_DEBUG: [PULSE] Latency: ${latency}ms | Count: ${_activeRegistry.length}");
        MissionControlService().record(MetricType.detectionCount, _activeRegistry.length.toDouble());
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Heartbeat Stutter: $e");
    }
  }

  List<DetectionCandidate> _parseRaw(String text) {
    final List<dynamic> list = jsonDecode(text);
    return list.map((item) {
      final label = item['label'].toString().toUpperCase();
      final List<num> box = List<num>.from(item['box_2d']);
      return DetectionCandidate(
        id: "${label}_${box[0]}",
        objectLabel: label,
        relativeLocation: Rect.fromLTRB(box[0]/1000, box[1]/1000, box[2]/1000, box[3]/1000),
        isLiving: label.contains("MAN") || label.contains("PERSON"),
      );
    }).toList();
  }
}