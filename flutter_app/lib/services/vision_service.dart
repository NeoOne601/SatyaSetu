/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 63.0.0
 * PHASE: Phase 44.0 (Robust Metal Sync)
 * FIX: 
 * 1. Kill-Switch: 10s timeout on server requests to prevent UI lockup.
 * 2. Error Resilience: Hard-resets the '_busy' flag if the server hangs.
 * 3. Metal Resizer: Maintained high-performance GPU-bound scaling.
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
    debugPrint("flutter: SATYA_DEBUG: [VISION] Metal Pipeline Engaged.");
    macController = controller;
    _isRunning = true;
    _runNeuralLoop();
  }

  Future<void> initialize() async {
    if (Platform.isMacOS) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Silicon Ready.");
    }
  }

  Future<void> _runNeuralLoop() async {
    while (_isRunning) {
      if (!_busy && macController != null) {
        await _performRealWorldAnalysis();
      }
      // Increased to 2.5s to allow M1 thermal recovery given your logs
      await Future.delayed(const Duration(milliseconds: 2500));
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
    } catch (e) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  Future<void> _performRealWorldAnalysis() async {
    if (_busy) return;
    _busy = true;
    
    _statusController.add("Eyes Sensing...");
    
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
      _statusController.add(results.isEmpty ? "Scanning..." : "Target Locked");
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Sync Exception: $e");
    } finally {
      _busy = false; 
    }
  }

  Future<List<DetectionCandidate>> _queryLocalEngine(Uint8List imageBytes) async {
    const url = "http://127.0.0.1:8000/v1/vision"; 
    final base64Image = base64Encode(imageBytes);
    
    try {
      // 10s TIMEOUT: Kills the request if the server thermal throttles
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"images": [base64Image]})
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawResponse = data['response'] ?? "[]";
        return _parseDynamicSemanticJson(rawResponse);
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Server Timeout/Hang.");
    }
    return [];
  }

  List<DetectionCandidate> _parseDynamicSemanticJson(String text) {
    try {
      final List<dynamic> list = jsonDecode(text);
      List<DetectionCandidate> candidates = [];
      
      final livingKeywords = ["MAN", "WOMAN", "BOY", "GIRL", "CHILD", "SISTER", "SON", "PERSON", "FACE", "HEAD"];
      final interactionKeywords = ["HOLDING", "WEARING", "CARRYING", "USING", "TOUCHING", "HAND"];

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

        bool mentionsLiving = livingKeywords.any((w) => label.contains(w));
        bool mentionsInteraction = interactionKeywords.any((w) => label.contains(w));
        bool isLiving = mentionsLiving && !mentionsInteraction;

        candidates.add(DetectionCandidate(
          objectLabel: label,
          personaType: "SILICON",
          confidence: 0.99,
          relativeLocation: rect,
          isLiving: isLiving,
        ));
      }
      
      candidates.sort((a, b) => 
        (b.relativeLocation.width * b.relativeLocation.height)
        .compareTo(a.relativeLocation.width * a.relativeLocation.height));

      return candidates;
    } catch (e) {
      return [];
    }
  }

  void stop() => _isRunning = false;
}