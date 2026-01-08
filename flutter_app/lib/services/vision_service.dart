/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 100.0.0
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: Industrial Vision Pulse with Camera Warmup Protocol.
 * FIX: Added warm-up delay after camera attachment.
 * FIX: Added retry logic for transient camera capture failures.
 * FIX: Graceful degradation when camera is unavailable.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera_macos/camera_macos.dart';

class DetectionCandidate {
  final String id;
  final String objectLabel;
  final Rect relativeLocation; 
  DetectionCandidate({required this.id, required this.objectLabel, required this.relativeLocation});
}

class VisionService {
  CameraMacOSController? macController; 
  bool _isRunning = false;
  bool isPaused = false;
  bool _pulseActive = false;
  int _consecutiveFailures = 0;
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;

  void initialize() => debugPrint("flutter: SATYA_DEBUG: [VISION] Industrial Protocol v100 Ready.");

  void attachCamera(CameraMacOSController controller) async {
    macController = controller;
    debugPrint("flutter: SATYA_DEBUG: [VISION] Camera attached. Starting warmup...");
    
    // CRITICAL: Allow camera hardware to stabilize before taking pictures
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("flutter: SATYA_DEBUG: [VISION] Warmup complete. Starting pulse loop.");
    
    _isRunning = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_isRunning) {
      if (macController != null && !isPaused && !_pulseActive) {
        await _performPulse();
      }
      // Adaptive delay: slow down if camera is failing repeatedly
      final delay = _consecutiveFailures > 3 ? 2000 : 800;
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  Future<void> _performPulse() async {
    _pulseActive = true; 
    try {
      // Attempt capture with retry logic
      Uint8List? imageBytes;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final CameraMacOSFile? rawData = await macController!.takePicture();
          if (rawData?.bytes != null && rawData!.bytes!.isNotEmpty) {
            imageBytes = Uint8List.fromList(rawData.bytes!);
            break;
          }
        } catch (captureError) {
          debugPrint("flutter: SATYA_DEBUG: [VISION] Capture attempt $attempt failed: $captureError");
          if (attempt == 0) await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (imageBytes == null) {
        _consecutiveFailures++;
        if (_consecutiveFailures % 5 == 1) {
          debugPrint("flutter: SATYA_DEBUG: [VISION] Camera capture failing. Failures: $_consecutiveFailures");
        }
        return;
      }
      
      _consecutiveFailures = 0; // Reset on success

      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/v1/vision"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(imageBytes)]})
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = jsonDecode(data['response']) as List;
        final candidates = list.map((item) {
          return DetectionCandidate(
            id: item['label'],
            objectLabel: item['label'],
            relativeLocation: Rect.fromLTRB(
              item['box_2d'][0]/1000, 
              item['box_2d'][1]/1000, 
              item['box_2d'][2]/1000, 
              item['box_2d'][3]/1000
            ),
          );
        }).toList();
        _candidatesController.add(candidates);
        debugPrint("flutter: SATYA_DEBUG: [VISION] Detected ${candidates.length} objects.");
      }
    } catch (e) {
      debugPrint("flutter: VISION_STUTTER: $e");
    } finally {
      _pulseActive = false;
    }
  }
}