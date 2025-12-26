/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 1.8.0
 * PHASE: Phase 7.3 (Dual-Platform Camera Support)
 * DESCRIPTION: 
 * Orchestrates the visual intelligence pipeline with support for both mobile
 * and macOS cameras.
 * PURPOSE:
 * Analyzes camera frames to detect "Visual Anchors" (Rickshaws, Books, Utensils).
 * Broadcasts RecognizedIntent enums to trigger UI persona morphing.
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

// Platform-specific camera imports
import 'package:camera/camera.dart' as mobile_camera;
import 'package:camera_macos/camera_macos.dart' as macos_camera;

/// Supported visual personas based on detected physical objects.
enum RecognizedIntent {
  none,
  rideHailing,   // Recognized: Rickshaw / Auto / Car
  laborRepair,    // Recognized: Tools / Wrench
  education,      // Recognized: Books / Pen
  householdAsset, // Recognized: Utensils / Household items
}

class VisionService {
  // Mobile camera controller (Android/iOS)
  mobile_camera.CameraController? mobileController;
  
  // macOS camera controller
  macos_camera.CameraMacOSController? macOSController;
  
  ObjectDetector? _objectDetector;
  bool _isProcessing = false;
  
  final _intentStreamController = StreamController<RecognizedIntent>.broadcast();
  VoidCallback? onInitialized;
  
  /// Stream that the UI listens to for real-time adaptive UI morphing.
  Stream<RecognizedIntent> get intentStream => _intentStreamController.stream;

  /// Returns true if running on macOS platform
  bool get _isMacOS => Platform.isMacOS;
  
  /// Returns true if camera is initialized
  bool get isInitialized {
    if (_isMacOS) {
      return macOSController != null;
    } else {
      return mobileController?.value.isInitialized ?? false;
    }
  }
  
  /// Get the mobile camera controller for UI preview (Android/iOS only)
  mobile_camera.CameraController? get mobileCamera => mobileController;

  /// PRINCIPAL DESIGN: Vision Mocking
  /// Purpose: Allows testing the Adaptive UI logic on restricted hardware or emulators.
  void mockDetection(RecognizedIntent intent) {
    print("SATYA_VISION: Mocking detection of $intent");
    _intentStreamController.add(intent);
  }

  /// INITIALIZATION: Triggers camera hardware and loads the AI model.
  /// Purpose: Platform-aware camera initialization for mobile and macOS.
  Future<void> initialize() async {
    try {
      // PLATFORM CHECK: Initialize appropriate camera based on platform
      if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
        print("SATYA_VISION: Unsupported platform for camera.");
        return;
      }

      if (_isMacOS) {
        await _initializeMacOSCamera();
      } else {
        await _initializeMobileCamera();
      }
    } catch (e) {
      print("SATYA_VISION_ERR: Initialization failed: $e");
    }
  }

  /// Initialize macOS camera using camera_macos package
  Future<void> _initializeMacOSCamera() async {
    print("SATYA_VISION: Initializing macOS camera...");
    
    // Note: macOS camera controller is initialized via the CameraMacOSView widget
    // We'll receive the controller in the onCameraInitialized callback from the UI
    // For now, just notify that we're ready for initialization
    print("SATYA_VISION: macOS camera ready for widget initialization.");
  }
  
  /// Called by the UI when macOS camera widget is initialized
  void onMacOSCameraInitialized(macos_camera.CameraMacOSController controller) {
    macOSController = controller;
    print("SATYA_VISION: macOS camera initialized successfully.");
    
    // Start image streaming for object detection
    _startMacOSImageStream();
    
    // Notify UI
    if (onInitialized != null) onInitialized!();
  }

  /// Initialize mobile camera (Android/iOS)
  Future<void> _initializeMobileCamera() async {
    print("SATYA_VISION: Initializing mobile camera...");
    
    // 1. Initialize the Object Detector (MediaPipe/TFLite) - Mobile only
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: false,
    );
    _objectDetector = ObjectDetector(options: options);

    // 2. Locate and initialize Camera hardware (Android/iOS only)
    final cameras = await mobile_camera.availableCameras();
    if (cameras.isEmpty) {
      print("SATYA_VISION: No cameras found.");
      return;
    }

    mobileController = mobile_camera.CameraController(
      cameras[0],
      mobile_camera.ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? mobile_camera.ImageFormatGroup.yuv420 : null,
    );

    await mobileController!.initialize();
    print("SATYA_VISION: Mobile camera initialized successfully.");
    
    // 3. Notify UI that the feed is ready
    if (onInitialized != null) onInitialized!();
    
    // 4. Start inference stream for mobile targets
    _startMobileImageStream();
  }

  /// Start image streaming for macOS camera
  void _startMacOSImageStream() {
    macOSController?.startImageStream((macos_camera.CameraImageData? imageData) {
      if (_isProcessing || imageData == null) return;
      _isProcessing = true;
      try {
        // TODO: Convert macOS CameraImageData to ML Kit compatible format
        // For now, just log that we're receiving frames
        // Future: Implement object detection on macOS frames
      } finally {
        _isProcessing = false;
      }
    });
    print("SATYA_VISION: macOS image stream started.");
  }

  /// INFERENCE STREAM: Analyzes frames for visual anchors (Mobile).
  void _startMobileImageStream() {
    mobileController?.startImageStream((mobile_camera.CameraImage image) async {
      if (_isProcessing || _objectDetector == null) return;
      _isProcessing = true;
      try {
        // AI detection logic for rickshaws, utensils, and pens will reside here.
        // On confidence > 70%, we broadcast the RecognizedIntent.
      } finally {
        _isProcessing = false;
      }
    });
    print("SATYA_VISION: Mobile image stream started.");
  }

  /// Stop image streaming
  void stopImageStream() {
    if (_isMacOS) {
      macOSController?.stopImageStream();
    } else {
      mobileController?.stopImageStream();
    }
  }

  /// Clean up hardware and AI model resources.
  void dispose() {
    mobileController?.dispose();
    macOSController?.destroy();
    _objectDetector?.close();
    _intentStreamController.close();
  }
}