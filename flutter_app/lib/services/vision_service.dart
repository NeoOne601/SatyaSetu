/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 1.7.1
 * PHASE: Phase 7.1 (The Lens of Reality)
 * DESCRIPTION: 
 * Manages the camera hardware and visual object recognition stream.
 * PURPOSE:
 * Bridges raw camera frames to high-level 'RecognizedIntent' enums.
 * Enables the UI to adapt based on visual anchors (Rickshaws, Utensils).
 */

import 'dart:async';
import 'package:camera/camera.dart';

/// Supported visual personas based on detected objects.
enum RecognizedIntent {
  none,
  rideHailing,   // Triggered by Rickshaw/Car
  laborRepair,    // Triggered by Tools
  education,      // Triggered by Books
  householdAsset, // Triggered by Utensils/Household items
}

class VisionService {
  CameraController? controller;
  final _intentStreamController = StreamController<RecognizedIntent>.broadcast();
  
  /// UI components subscribe to this stream to trigger "Morphing".
  Stream<RecognizedIntent> get intentStream => _intentStreamController.stream;

  /// PRINCIPAL DESIGN: Vision Mocking
  /// Purpose: Allows testing Adaptive UI on emulators where camera access is restricted.
  void mockDetection(RecognizedIntent intent) {
    print("SATYA_VISION: Mocking detection of $intent");
    _intentStreamController.add(intent);
  }

  /// INITIALIZATION: Triggers camera hardware link.
  /// Purpose: Establishes the 'Eyes' of the application.
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await controller!.initialize();
      print("SATYA_VISION: Camera Hardware Link Established.");
    } catch (e) {
      print("SATYA_VISION_ERR: Hardware trigger failed: $e");
    }
  }

  /// Releases camera hardware and closes streams.
  void dispose() {
    controller?.dispose();
    _intentStreamController.close();
  }
}