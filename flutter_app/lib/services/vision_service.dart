/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 69.0.0
 * PHASE: Phase 48.0 (Semantic Consensus)
 * AUTHOR: SatyaSetu Internal Neural Team
 * DESCRIPTION: Handles vision data and binds situational context to objects.
 * Implements category-aware de-duplication to prevent pen/hand overlap issues.
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
import '../models/intent_models.dart';
import 'intent_engine.dart';

class DetectionCandidate {
  final String objectLabel;
  final Rect relativeLocation; 
  final bool isLiving;
  final SituationState situation; 
  
  DetectionCandidate({
    required this.objectLabel, 
    required this.relativeLocation,
    required this.isLiving,
    required this.situation,
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
    debugPrint("flutter: SATYA_DEBUG: [VISION] Situational Pipeline Active.");
    macController = controller;
    _isRunning = true;
    _runNeuralLoop();
  }

  Future<void> initialize() async {
    if (Platform.isMacOS) debugPrint("flutter: SATYA_DEBUG: [VISION] Silicon Ready.");
  }

  Future<void> _runNeuralLoop() async {
    while (_isRunning) {
      if (!_busy && macController != null) {
        await _performRealWorldAnalysis();
      }
      // Fluid refresh optimized for M1
      await Future.delayed(const Duration(milliseconds: 2200));
    }
  }

  Future<Uint8List?> _resizeHardware(Uint8List rawBytes) async {
    ui.Image? image;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(rawBytes, targetWidth: 768);
      final ui.FrameInfo fi = await codec.getNextFrame();
      image = fi.image;
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) { return null; } finally { image?.dispose(); }
  }

  Future<void> _performRealWorldAnalysis() async {
    if (_busy) return;
    _busy = true;
    try {
      final CameraMacOSFile? rawData = await macController!.takePicture();
      if (rawData?.bytes == null) { _busy = false; return; }
      final processed = await _resizeHardware(rawData!.bytes!);
      if (processed == null) { _busy = false; return; }

      final results = await _queryLocalEngine(processed);
      _candidatesController.add(results);
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Loop Interrupted.");
    } finally {
      _busy = false; 
    }
  }

  Future<List<DetectionCandidate>> _queryLocalEngine(Uint8List imageBytes) async {
    const url = "http://127.0.0.1:8000/v1/vision"; 
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Encode(imageBytes)]})
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseAndConsolidate(data['response'] ?? "[]");
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Bridge Connectivity Lost.");
    }
    return [];
  }

  List<DetectionCandidate> _parseAndConsolidate(String text) {
    try {
      final List<dynamic> list = jsonDecode(text);
      List<DetectionCandidate> rawCandidates = [];
      
      final livingWords = ["MAN", "WOMAN", "BOY", "GIRL", "CHILD", "SISTER", "SON", "PERSON", "FACE", "HEAD"];
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

        rawCandidates.add(DetectionCandidate(
          objectLabel: label,
          relativeLocation: rect,
          isLiving: hasLiving && !hasAction,
          situation: IntentEngine.decode(label),
        ));
      }

      // CATEGORY-AWARE NMS: Merges boxes of same color, preserves objects inside hands.
      List<DetectionCandidate> consolidated = [];
      for (var candidate in rawCandidates) {
        bool shouldAdd = true;
        for (var existing in consolidated) {
          final intersection = candidate.relativeLocation.intersect(existing.relativeLocation);
          final overlapRatio = (intersection.width * intersection.height) / 
                               (candidate.relativeLocation.width * candidate.relativeLocation.height);
          
          if (candidate.isLiving == existing.isLiving && overlapRatio > 0.65) {
            shouldAdd = false;
            break;
          }
        }
        if (shouldAdd) consolidated.add(candidate);
      }

      consolidated.sort((a, b) => 
        (b.relativeLocation.width * b.relativeLocation.height)
        .compareTo(a.relativeLocation.width * a.relativeLocation.height));

      return consolidated;
    } catch (e) { return []; }
  }

  void stop() => _isRunning = false;
}