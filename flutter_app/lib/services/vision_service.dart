/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 1.7.4
 * PHASE: Phase 7.2 (Object Classification)
 * DESCRIPTION: 
 * Manages the transition from raw hardware frames to semantic 'RecognizedIntents'.
 * PURPOSE:
 * Bridges platform-specific cameras to the unified UI intent stream.
 * Supports iMac testing via 'camera_macos' and mobile via standard 'camera'.
 */

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';

/// Semantic intents that trigger adaptive UI personas (Ride, House, Education).
enum RecognizedIntent {
  none,
  rideHailing,   // Recognized: Auto-Rickshaw / Car
  laborRepair,    // Recognized: Tools / Wrench / Utensils
  education,      // Recognized: Books / Pens
  householdAsset, // Recognized: General Home Items
}

class VisionService {
  // Target: Mobile (Android/iOS)
  CameraController? mobileController;
  
  // Target: iMac (macOS)
  CameraMacOSController? macController;
  
  final _intentStreamController = StreamController<RecognizedIntent>.broadcast();
  VoidCallback? onInitialized;
  
  /// Stream used by the Home Screen to morph contextually.
  Stream<RecognizedIntent> get intentStream => _intentStreamController.stream;

  /// PRINCIPAL DESIGN: Vision Mocking
  /// Purpose: Validates Phase 7 adaptive logic when physical objects aren't available.
  void mockDetection(RecognizedIntent intent) {
    print("SATYA_VISION: Simulation active: $intent");
    _intentStreamController.add(intent);
  }

  /// INITIALIZATION: Strategic Hardware Handshake.
  /// Purpose: Configures the correct native channel for either iMac or Mobile.
  Future<void> initialize() async {
    if (Platform.isMacOS) {
      print("SATYA_VISION: Attempting iMac AVFoundation link...");
      // For macOS, the View widget handles the camera start.
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
        print("SATYA_VISION: Mobile Trinity Camera Active.");
        if (onInitialized != null) onInitialized!();
      } catch (e) {
        print("SATYA_VISION_ERR: Mobile hardware trigger failed: $e");
      }
    }
  }

  /// Releases hardware handles to free the lens for other apps.
  void dispose() {
    mobileController?.dispose();
    _intentStreamController.close();
  }
}