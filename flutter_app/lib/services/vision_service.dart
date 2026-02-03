/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 111.0.0
 * AUTHOR: SatyaSetu Principal Engineer
 * PHASE: Phase 11 (The Cortex - Local Persistence)
 * DESCRIPTION: 
 * Industrial Vision Pulse with Trust Graph integration.
 * Enriches detections with local trust scores from SQLite Cortex.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera_macos/camera_macos.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

// Import Mission Control to report data
import 'mission_control_service.dart';
import '../models/telemetry_models.dart';

// Phase 11: Import Database Service for Trust Graph
import 'database_service.dart';

// TODO: Ensure this IP matches your Mac's local IP (e.g. 192.168.1.x)
const String _kServerUrl = "http://192.168.0.174:8000/v1/vision";

/// Detection candidate enriched with Trust Graph data
class DetectionCandidate {
  final String id;
  final String objectLabel;
  final Rect relativeLocation;
  final double trustScore;  // Phase 11: Local trust score (0.0-1.0)
  final String? geohash;    // Phase 11: Spatial index
  
  DetectionCandidate({
    required this.id, 
    required this.objectLabel, 
    required this.relativeLocation,
    this.trustScore = 0.5,  // Default neutral trust
    this.geohash,
  });
  
  /// Check if this entity is trusted (>= 70%)
  bool get isTrusted => trustScore >= 0.7;
  
  /// Check if this entity is untrusted (< 30%)
  bool get isUntrusted => trustScore < 0.3;
  
  /// Get trust level as a human-readable string
  String get trustLevel {
    if (trustScore >= 0.8) return 'Verified';
    if (trustScore >= 0.6) return 'Trusted';
    if (trustScore >= 0.4) return 'Neutral';
    if (trustScore >= 0.2) return 'Caution';
    return 'Untrusted';
  }
  
  /// Get trust percentage for display
  int get trustPercentage => (trustScore * 100).round();
}

class VisionService {
  CameraMacOSController? macController; 
  CameraController? mobileController; 

  bool _isRunning = false;
  bool isPaused = false;
  bool _pulseActive = false;
  int _consecutiveFailures = 0;
  
  // Phase 11: Database service for Trust Graph
  final DatabaseService _db = DatabaseService();
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;

  void initialize() {
    debugPrint("flutter: SATYA_DEBUG: [VISION] Industrial Protocol v111 Ready (Trust Graph Enabled).");
    // Clean up expired cache on startup
    _db.clearExpiredCache();
  }

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

  /// Phase 15: Compress image before network transmission
  Uint8List _compressImage(Uint8List bytes, {int maxWidth = 640}) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      
      if (decoded.width > maxWidth) {
        final resized = img.copyResize(decoded, width: maxWidth);
        return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
      }
      return bytes;
    } catch (e) {
      debugPrint("flutter: VISION_COMPRESS_ERROR: $e");
      return bytes;
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

      // Phase 15: Compress image before sending
      final compressedBytes = _compressImage(imageBytes);

      final response = await http.post(
        Uri.parse(_kServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(compressedBytes)]})
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = jsonDecode(data['response']) as List;
        
        // Phase 11: Enrich detections with Trust Graph data
        final candidates = await Future.wait(list.map((item) async {
          final label = item['label'] as String;
          
          // Remember entity in Trust Graph (updates last_seen or creates new)
          final entity = await _db.rememberEntity(label);
          
          return DetectionCandidate(
            id: entity.id,
            objectLabel: label,
            relativeLocation: Rect.fromLTRB(
              item['box_2d'][0]/1000, 
              item['box_2d'][1]/1000, 
              item['box_2d'][2]/1000, 
              item['box_2d'][3]/1000
            ),
            trustScore: entity.trustScore,  // Enriched from local Cortex
            geohash: entity.geohash,
          );
        }));
        
        _candidatesController.add(candidates);
        
        // --- TELEMETRY UPLINK ---
        // Report detection count to the Brain (Mission Control)
        MissionControlService().record(MetricType.detectionCount, candidates.length.toDouble());
        
        debugPrint("flutter: SATYA_DEBUG: [VISION] Detected ${candidates.length} objects (Trust Graph synced).");
      }
    } catch (e) {
      debugPrint("flutter: VISION_STUTTER: $e");
    } finally {
      _pulseActive = false;
    }
  }
  
  /// Pause vision processing (e.g., when drawer opens)
  void pause() {
    isPaused = true;
    debugPrint("flutter: SATYA_DEBUG: [VISION] Paused (battery save mode).");
  }
  
  /// Resume vision processing
  void resume() {
    isPaused = false;
    debugPrint("flutter: SATYA_DEBUG: [VISION] Resumed.");
  }
  
  /// Stop vision processing completely
  void stop() {
    _isRunning = false;
    debugPrint("flutter: SATYA_DEBUG: [VISION] Stopped.");
  }
  
  /// Dispose resources
  void dispose() {
    stop();
    _candidatesController.close();
  }
}