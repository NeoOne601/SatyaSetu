/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 1.8.0
 * PHASE: Phase 7.2 (The Hybrid Lens)
 * PURPOSE: Maintains object discovery for adoption while ensuring stable platform switching.
 */

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';

class DetectionCandidate {
  final String label;
  final RecognizedIntent intent;
  final double confidence;
  DetectionCandidate({required this.label, required this.intent, required this.confidence});
}

enum RecognizedIntent { none, rideHailing, laborRepair, education, householdAsset }
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
      _runIMacDiscoveryProbe();
    } else {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) return;
        mobileController = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
        await mobileController!.initialize();
        if (onInitialized != null) onInitialized!();
      } catch (e) { print("SATYA_VISION_ERR: $e"); }
    }
  }

  /// PROBE: Simulates object detection on iMac for Phase 7.2 testing.
  void _runIMacDiscoveryProbe() {
    Timer.periodic(const Duration(seconds: 4), (timer) {
      final candidates = timer.tick % 2 == 0 
        ? [DetectionCandidate(label: "Reference Book", intent: RecognizedIntent.education, confidence: 0.98)]
        : [DetectionCandidate(label: "Auto Rickshaw", intent: RecognizedIntent.rideHailing, confidence: 0.92)];
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