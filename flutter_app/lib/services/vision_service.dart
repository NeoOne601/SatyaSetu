/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 1.7.2
 * PHASE: Phase 7.2 (Object Classification)
 * DESCRIPTION: 
 * Dual-path camera controller for macOS and Mobile (Android/iOS).
 * PURPOSE:
 * Bridges hardware frames to 'RecognizedIntent' enums. 
 * Supports standard 'camera' for mobile and 'camera_macos' for iMac.
 */

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';

/// Semantics of recognized objects that trigger adaptive UI personas.
enum RecognizedIntent {
  none,
  rideHailing,   // Rickshaw/Car
  laborRepair,    // Tools/Utensils
  education,      // Books/Pens
  householdAsset, // General items
}

class VisionService {
  // Mobile Controller
  CameraController? mobileController;
  
  // macOS Controller
  CameraMacOSController? macController;
  
  final _intentStreamController = StreamController<RecognizedIntent>.broadcast();
  VoidCallback? onInitialized;
  
  Stream<RecognizedIntent> get intentStream => _intentStreamController.stream;

  /// PRINCIPAL DESIGN: Vision Mocking.
  /// Purpose: Validates UI morphing when hardware detection is unavailable.
  void mockDetection(RecognizedIntent intent) {
    print("SATYA_VISION: Mocking detection of $intent");
    _intentStreamController.add(intent);
  }

  /// INITIALIZATION: Strategic hardware handshake.
  Future<void> initialize() async {
    if (Platform.isMacOS) {
      print("SATYA_VISION: Initializing iMac Camera via AVFoundation...");
      // macOS uses the CameraMacOSView widget which handles its own initialization
      // We set a flag or trigger a rebuild once the view signals readiness.
      if (onInitialized != null) onInitialized!();
    } else {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) return;

        mobileController = CameraController(
          cameras[0],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        );

        await mobileController!.initialize();
        print("SATYA_VISION: Mobile Camera Active.");
        if (onInitialized != null) onInitialized!();
      } catch (e) {
        print("SATYA_VISION_ERR: Mobile hardware trigger failed: $e");
      }
    }
  }

  /// Dispose resources for both platform paths.
  void dispose() {
    mobileController?.dispose();
    _intentStreamController.close();
  }
}