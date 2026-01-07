**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 87.0.0
 * AUTHOR: SatyaSetu Principal Engineer
 * FIX: Increased timeout to 20s to accommodate even the slowest inference spikes.
 * FIX: Added aggressive error handling to keep the loop alive even if one frame fails.
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/intent_models.dart';
import '../models/telemetry_models.dart';
import 'mission_control_service.dart';
import 'package:camera_macos/camera_macos.dart';

class DetectionCandidate {
  final String id;
  final String objectLabel;
  final Rect relativeLocation; 
  final ApeResponse? fusedPlan;

  DetectionCandidate({required this.id, required this.objectLabel, required this.relativeLocation, this.fusedPlan});
}

class VisionService {
  CameraMacOSController? macController; 
  bool _isRunning = false;
  bool isPaused = false;
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;

  void initialize() => debugPrint("flutter: SATYA_DEBUG: [VISION] Speed-Optimized Pulse Online.");

  void attachCamera(CameraMacOSController controller) {
    macController = controller;
    _isRunning = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_isRunning) {
      if (macController != null && !isPaused) {
        await _performPulse();
      }
      // Increased delay to allow server to cool down between pulses
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _performPulse() async {
    try {
      final CameraMacOSFile? rawData = await macController!.takePicture();
      if (rawData?.bytes == null) return;
      
      final response = await http.post(
        Uri.parse("[http://127.0.0.1:8000/v1/vision](http://127.0.0.1:8000/v1/vision)"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(rawData!.bytes!)]})
      ).timeout(const Duration(seconds: 20)); // STABILITY FIX: Extended timeout
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = jsonDecode(data['response']) as List;
        final candidates = list.map((item) {
          return DetectionCandidate(
            id: item['label'],
            objectLabel: item['label'],
            relativeLocation: Rect.fromLTRB(item['box_2d'][0]/1000, item['box_2d'][1]/1000, item['box_2d'][2]/1000, item['box_2d'][3]/1000),
            fusedPlan: item['ape_plan'] != null ? ApeResponse.fromJson(item['ape_plan']) : null,
          );
        }).toList();
        _candidatesController.add(candidates);
      }
    } catch (e) {
      // Log but do not crash the loop
      debugPrint("VISION_HEARTBEAT_SKIP: $e");
    }
  }
}