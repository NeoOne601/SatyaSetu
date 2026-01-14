/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 100.2.0
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: Industrial Vision Pulse with Network Configuration.
 * CHANGE: Updated server URL to point to Mac's local IP for physical device testing.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera_macos/camera_macos.dart';
import 'package:camera/camera.dart';

// TODO: REPLACE '192.168.1.5' WITH YOUR MAC'S ACTUAL IP ADDRESS
const String _kServerUrl = "http://192.168.0.174:8000/v1/vision";

class DetectionCandidate {
  final String id;
  final String objectLabel;
  final Rect relativeLocation; 
  DetectionCandidate({required this.id, required this.objectLabel, required this.relativeLocation});
}

class VisionService {
  CameraMacOSController? macController; 
  CameraController? mobileController; 

  bool _isRunning = false;
  bool isPaused = false;
  bool _pulseActive = false;
  int _consecutiveFailures = 0;
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;

  void initialize() => debugPrint("flutter: SATYA_DEBUG: [VISION] Industrial Protocol v100 Ready.");

  // macOS Entry Point
  void attachCamera(CameraMacOSController controller) async {
    macController = controller;
    _startWarmupAndLoop("macOS");
  }

  // iOS/Android Entry Point
  void attachMobileCamera(CameraController controller) async {
    mobileController = controller;
    _startWarmupAndLoop("Mobile");
  }

  Future<void> _startWarmupAndLoop(String platform) async {
    debugPrint("flutter: SATYA_DEBUG: [VISION] $platform Camera attached. Starting warmup...");
    // CRITICAL: Allow camera hardware to stabilize before taking pictures
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("flutter: SATYA_DEBUG: [VISION] Warmup complete. Starting pulse loop.");
    _isRunning = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_isRunning) {
      // Check if EITHER controller is available and active
      bool canPulse = (macController != null || mobileController != null) && !isPaused && !_pulseActive;
      
      if (canPulse) {
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
          if (Platform.isMacOS && macController != null) {
            // macOS Capture
            final CameraMacOSFile? rawData = await macController!.takePicture();
            if (rawData?.bytes != null && rawData!.bytes!.isNotEmpty) {
              imageBytes = Uint8List.fromList(rawData.bytes!);
            }
          } else if (mobileController != null && mobileController!.value.isInitialized) {
            // iOS/Android Capture
            final XFile file = await mobileController!.takePicture();
            imageBytes = await file.readAsBytes();
          }

          if (imageBytes != null && imageBytes.isNotEmpty) break;

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

      // Use the local network IP instead of localhost
      final response = await http.post(
        Uri.parse(_kServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(imageBytes)]})
      ).timeout(const Duration(seconds: 5)); // Lower timeout for responsiveness
      
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
      } else {
         debugPrint("flutter: SATYA_DEBUG: [SERVER ERROR] ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("flutter: VISION_STUTTER: $e");
    } finally {
      _pulseActive = false;
    }
  }
}