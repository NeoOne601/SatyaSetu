/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 100.3.0
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: Industrial Vision Pulse with Telemetry Uplink.
 * CHANGE: Integrated MissionControlService to fix "Waiting for Neural Heartbeat".
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera_macos/camera_macos.dart';
import 'package:camera/camera.dart';

// Import Mission Control to report data
import 'mission_control_service.dart';
import '../models/telemetry_models.dart';

// TODO: Ensure this IP matches your Mac's local IP (e.g. 192.168.1.x)
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
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("flutter: SATYA_DEBUG: [VISION] Warmup complete. Starting pulse loop.");
    _isRunning = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_isRunning) {
      bool canPulse = (macController != null || mobileController != null) && !isPaused && !_pulseActive;
      if (canPulse) {
        await _performPulse();
      }
      final delay = _consecutiveFailures > 3 ? 2000 : 800;
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  Future<void> _performPulse() async {
    _pulseActive = true; 
    try {
      Uint8List? imageBytes;
      
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          if (Platform.isMacOS && macController != null) {
            final CameraMacOSFile? rawData = await macController!.takePicture();
            if (rawData?.bytes != null && rawData!.bytes!.isNotEmpty) {
              imageBytes = Uint8List.fromList(rawData.bytes!);
            }
          } else if (mobileController != null && mobileController!.value.isInitialized) {
            final XFile file = await mobileController!.takePicture();
            imageBytes = await file.readAsBytes();
          }
          if (imageBytes != null && imageBytes.isNotEmpty) break;
        } catch (captureError) {
          if (attempt == 0) await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (imageBytes == null) {
        _consecutiveFailures++;
        // Report error to Mission Control (low frequency)
        if (_consecutiveFailures % 5 == 0) {
           MissionControlService().record(MetricType.detectionCount, 0.0); // Keep heartbeat alive
        }
        return;
      }
      
      _consecutiveFailures = 0;

      final response = await http.post(
        Uri.parse(_kServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(imageBytes)]})
      ).timeout(const Duration(seconds: 5));
      
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
        
        // --- TELEMETRY UPLINK ---
        // Report detection count to the Brain (Mission Control)
        MissionControlService().record(MetricType.detectionCount, candidates.length.toDouble());
        
        debugPrint("flutter: SATYA_DEBUG: [VISION] Detected ${candidates.length} objects.");
      }
    } catch (e) {
      debugPrint("flutter: VISION_STUTTER: $e");
    } finally {
      _pulseActive = false;
    }
  }
}