/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 77.0.0
 * PHASE: Phase 61.1 (Null-Safe Retina)
 * AUTHOR: SatyaSetu Neural Architect
 * FIX: 
 * 1. Build Fix: Implemented null-safe byte extraction to prevent crash.
 * 2. Scene Context: Exposes the Florence-detected environment to the UI.
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
  
  DetectionCandidate({
    required this.id,
    required this.objectLabel, 
    required this.relativeLocation,
    required this.isLiving,
  });
}

class VisionService {
  CameraMacOSController? macController; 
  bool _isRunning = false;
  bool _busy = false; 
  List<DetectionCandidate> _activeRegistry = [];
  String currentScene = "General environment";
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;

  Future<void> initialize() async {
    debugPrint("flutter: SATYA_DEBUG: [VISION] Neural Retina Ready.");
  }

  void attachCamera(CameraMacOSController controller) {
    macController = controller;
    _isRunning = true;
    _runNeuralLoop();
  }

  Future<void> _runNeuralLoop() async {
    while (_isRunning) {
      if (!_busy && macController != null) {
        await _performRealWorldAnalysis();
      }
      await Future.delayed(const Duration(milliseconds: 2200));
    }
  }

  Future<void> _performRealWorldAnalysis() async {
    if (_busy || macController == null) return;
    _busy = true;
    final stopwatch = Stopwatch()..start();
    
    try {
      final CameraMacOSFile? rawData = await macController!.takePicture();
      // FIX: Robust Null-Safe extraction for bytes
      final bytes = rawData?.bytes;
      if (bytes == null) { _busy = false; return; }
      
      const url = "http://127.0.0.1:8000/v1/vision"; 
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(bytes)]})
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentScene = data['context'] ?? "General environment";
        _activeRegistry = _parseRaw(data['response'] ?? "[]");
        _candidatesController.add(_activeRegistry);
        
        MissionControlService().record(MetricType.detectionCount, _activeRegistry.length.toDouble());
      }
    } catch (e) {
      MissionControlService().record(MetricType.errorRate, 1.0, metadata: e.toString());
    } finally {
      stopwatch.stop();
      MissionControlService().record(MetricType.latency, stopwatch.elapsedMilliseconds / 1000.0);
      _busy = false; 
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