/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 66.0.0
 * PHASE: Phase 45.1 (Semantic De-Duplication)
 * FIX: 
 * 1. Semantic NMS: Only merges boxes of the same color/category.
 * 2. Nested Persistence: Pens (Green) inside Humans (Red) are NEVER merged.
 * 3. Hardware Resizer: Re-implemented dart:ui scaling to stop iMac memory crashes.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DetectionCandidate {
  final String objectLabel;
  final String personaType;
  final double confidence;
  final Rect relativeLocation; 
  final bool isLiving;
  
  DetectionCandidate({
    required this.objectLabel, 
    required this.personaType, 
    required this.confidence,
    required this.relativeLocation,
    required this.isLiving,
  });
}

class VisionService {
  CameraMacOSController? macController; 
  bool _isRunning = false;
  bool _busy = false; 
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;
  Stream<String> get statusStream => _statusController.stream;

  void attachCamera(CameraMacOSController controller) {
    debugPrint("flutter: SATYA_DEBUG: [VISION] Semantic Pipeline Engaged.");
    macController = controller;
    _isRunning = true;
    _runNeuralLoop();
  }

  Future<void> initialize() async {
    if (Platform.isMacOS) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Ready.");
    }
  }

  Future<void> _runNeuralLoop() async {
    while (_isRunning) {
      if (!_busy && macController != null) {
        await _performRealWorldAnalysis();
      }
      // Delay allows M1 GPU to clear heat and Dart VM to collect garbage
      await Future.delayed(const Duration(milliseconds: 2200));
    }
  }

  /// GPU ACCELERATED RESIZER
  Future<Uint8List?> _resizeHardware(Uint8List rawBytes) async {
    ui.Image? image;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(rawBytes, targetWidth: 768);
      final ui.FrameInfo fi = await codec.getNextFrame();
      image = fi.image;
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Hardware Resize Fail.");
      return null;
    } finally {
      image?.dispose(); // MANDATORY: Frees Silicon VRAM
    }
  }

  Future<void> _performRealWorldAnalysis() async {
    if (_busy) return;
    _busy = true;
    
    try {
      final CameraMacOSFile? rawData = await macController!.takePicture();
      if (rawData == null || rawData.bytes == null) {
        _busy = false; return;
      }

      final Uint8List? processedBytes = await _resizeHardware(rawData.bytes!);
      if (processedBytes == null) {
        _busy = false; return;
      }

      final results = await _queryLocalEngine(processedBytes);
      _candidatesController.add(results);
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Hardware Stutter.");
    } finally {
      _busy = false; 
    }
  }

  Future<List<DetectionCandidate>> _queryLocalEngine(Uint8List imageBytes) async {
    const url = "http://127.0.0.1:8000/v1/vision"; 
    final base64Image = base64Encode(imageBytes);
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Image]})
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawResponse = data['response'] ?? "[]";
        return _parseAndConsolidate(rawResponse);
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Connection Timeout.");
    }
    return [];
  }

  /// SEMANTIC DE-DUPLICATOR
  List<DetectionCandidate> _parseAndConsolidate(String text) {
    try {
      final List<dynamic> list = jsonDecode(text);
      List<DetectionCandidate> rawCandidates = [];
      
      // Keywords that define living entities
      final livingWords = ["MAN", "WOMAN", "BOY", "GIRL", "CHILD", "SISTER", "SON", "PERSON", "FACE", "HEAD"];
      // Keywords that override living status to ensure pens/toys stay Green
      final actionWords = ["HOLDING", "WEARING", "CARRYING", "USING", "HAND", "PEN", "MARKER", "TOY", "MICKEY"];

      for (var item in list) {
        final label = item['label'].toString().toUpperCase();
        final List<num> box = List<num>.from(item['box_2d']);
        
        final rect = Rect.fromLTRB(
          box[0].toDouble() / 1000.0,
          box[1].toDouble() / 1000.0,
          box[2].toDouble() / 1000.0,
          box[3].toDouble() / 1000.0
        );

        if (rect.width * rect.height > 0.95) continue;

        bool hasLiving = livingWords.any((w) => label.contains(w));
        bool hasAction = actionWords.any((w) => label.contains(w));

        // CATEGORY LOGIC:
        // A pure human box is Red.
        // If it mentions an object or interaction, it's Green.
        bool isLiving = hasLiving && !hasAction;

        rawCandidates.add(DetectionCandidate(
          objectLabel: label,
          personaType: "SILICON",
          confidence: 0.99,
          relativeLocation: rect,
          isLiving: isLiving,
        ));
      }

      // CATEGORY-AWARE NON-MAXIMUM SUPPRESSION
      List<DetectionCandidate> consolidated = [];
      for (var candidate in rawCandidates) {
        bool shouldAdd = true;
        for (var existing in consolidated) {
          final intersection = candidate.relativeLocation.intersect(existing.relativeLocation);
          final overlapRatio = (intersection.width * intersection.height) / 
                               (candidate.relativeLocation.width * candidate.relativeLocation.height);
          
          // CRITICAL: Only merge if they are the SAME color category
          // This ensures the green pen is NOT deleted by the red arm box.
          if (candidate.isLiving == existing.isLiving && overlapRatio > 0.65) {
            shouldAdd = false;
            break;
          }
        }
        if (shouldAdd) consolidated.add(candidate);
      }

      // Sort: Smallest boxes on top
      consolidated.sort((a, b) => 
        (b.relativeLocation.width * b.relativeLocation.height)
        .compareTo(a.relativeLocation.width * a.relativeLocation.height));

      return consolidated;
    } catch (e) {
      return [];
    }
  }

  void stop() => _isRunning = false;
}