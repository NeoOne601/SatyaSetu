/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 71.0.0
 * PHASE: Phase 52.3 (Registry Sync)
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Corrects the candidate stream bug. Maintains a registry 
 * of detections to prevent pulses from overwriting the entire scene.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/intent_models.dart';
import 'intent_engine.dart';

class DetectionCandidate {
  final String id; // Unique instance ID
  final String objectLabel;
  final Rect relativeLocation; 
  final bool isLiving;
  SituationState? situation; 
  
  DetectionCandidate({
    required this.id,
    required this.objectLabel, 
    required this.relativeLocation,
    required this.isLiving,
    this.situation,
  });
}

class VisionService {
  CameraMacOSController? macController; 
  bool _isRunning = false;
  bool _busy = false; 
  
  // REGISTRY: Prevents stream corruption
  List<DetectionCandidate> _activeRegistry = [];
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;

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
    if (_busy) return;
    _busy = true;
    try {
      final CameraMacOSFile? rawData = await macController!.takePicture();
      if (rawData?.bytes == null) { _busy = false; return; }
      
      final rawResults = await _queryLocalEngine(rawData!.bytes!);
      
      // Update the registry with new detections
      _activeRegistry = rawResults;
      _candidatesController.add(_activeRegistry);
      
      final List<String> allLabels = rawResults.map((e) => e.objectLabel).toList();
      for (var candidate in rawResults) {
        _triggerReasoning(candidate, allLabels);
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Sync Delay.");
    } finally {
      _busy = false; 
    }
  }

  Future<void> _triggerReasoning(DetectionCandidate c, List<String> context) async {
    c.situation = await IntentEngine.resolve(c.objectLabel, context);
    // Broadcast the entire registry to update UI with this specific candidate's new state
    _candidatesController.add(_activeRegistry); 
  }

  Future<List<DetectionCandidate>> _queryLocalEngine(Uint8List imageBytes) async {
    const url = "http://127.0.0.1:8000/v1/vision"; 
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"images": [base64Encode(imageBytes)]})
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _parseRaw(data['response'] ?? "[]");
    }
    return [];
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
        isLiving: label.contains("MAN") || label.contains("PERSON") || label.contains("BOY"),
      );
    }).toList();
  }
}