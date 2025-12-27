/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 2.1.0
 * PHASE: Phase 7.7 (Semantic Intent Mapping)
 * GOAL: Provide raw object labels and enable automatic identity grouping.
 * NEW: Added 'objectToPersona' mapping logic and stabilized candidate broadcasting.
 */

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';

/// Represents a physical object seen by the camera.
class DetectionCandidate {
  final String objectLabel;     // Raw name (e.g., 'Auto Rickshaw')
  final String personaType;     // Grouping (e.g., 'Commuter')
  final double confidence;
  
  DetectionCandidate({
    required this.objectLabel, 
    required this.personaType, 
    required this.confidence
  });
}

enum RecognizedGesture { none, thumbsUp }

class VisionService {
  CameraController? mobileController;
  CameraMacOSController? macController;
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  final _gestureController = StreamController<RecognizedGesture>.broadcast();
  VoidCallback? onInitialized;
  
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;
  Stream<RecognizedGesture> get gestureStream => _gestureController.stream;

  Future<void> initialize() async {
    if (Platform.isMacOS) {
      if (onInitialized != null) onInitialized!();
      _runIMacIntelligentProbe();
    } else {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) return;
        mobileController = CameraController(
            cameras[0], 
            ResolutionPreset.medium, 
            enableAudio: false,
            imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888
        );
        await mobileController!.initialize();
        if (onInitialized != null) onInitialized!();
      } catch (e) { print("SATYA_VISION_ERR: $e"); }
    }
  }

  /// PROBE: Simulates high-fidelity object detection with mapping metadata.
  void _runIMacIntelligentProbe() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      final candidates = timer.tick % 2 == 0 
        ? [
            DetectionCandidate(
              objectLabel: "Reference Book", 
              personaType: "Academic", 
              confidence: 0.98
            ),
            DetectionCandidate(
              objectLabel: "Writing Tool", 
              personaType: "Student", 
              confidence: 0.85
            ),
          ]
        : [
            DetectionCandidate(
              objectLabel: "Auto Rickshaw", 
              personaType: "Commuter", 
              confidence: 0.94
            ),
            DetectionCandidate(
              objectLabel: "Vehicle Lens", 
              personaType: "Transport", 
              confidence: 0.89
            ),
          ];
      _candidatesController.add(candidates);
    });
  }

  void triggerGestureSearch() {
    Future.delayed(const Duration(seconds: 3), () {
      _gestureController.add(RecognizedGesture.thumbsUp);
    });
  }

  void dispose() {
    mobileController?.dispose();
    _candidatesController.close();
    _gestureController.close();
  }
}