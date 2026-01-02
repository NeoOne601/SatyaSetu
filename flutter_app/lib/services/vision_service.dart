/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 67.0.0
 * PHASE: Phase 47.2 (Situational Injection)
 * FIX: Now maps detections to the IntentEngine to provide SituationState.
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
  final SituationState situation; // NEW: Bound intent state
  
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
    debugPrint("flutter: SATYA_DEBUG: [VISION] Intent Pipeline Engaged.");
    macController = controller;
    _isRunning = true;
    _runNeuralLoop();
  }

  Future<void> initialize() async {
    if (Platform.isMacOS) debugPrint("flutter: SATYA_DEBUG: [VISION] Ready.");
  }

  Future<void> _runNeuralLoop() async {
    while (_isRunning) {
      if (!_busy && macController != null) await _performRealWorldAnalysis();
      await Future.delayed(const Duration(milliseconds: 2000));
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
    } catch (e) { debugPrint("flutter: SATYA_DEBUG: [VISION] Loop Fail."); } finally { _busy = false; }
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
        return _parseAndMap(data['response'] ?? "[]");
      }
    } catch (e) { debugPrint("flutter: SATYA_DEBUG: [VISION] Offline."); }
    return [];
  }

  List<DetectionCandidate> _parseAndMap(String text) {
    try {
      final List<dynamic> list = jsonDecode(text);
      List<DetectionCandidate> candidates = [];
      
      final livingWords = ["MAN", "WOMAN", "BOY", "GIRL", "CHILD", "PERSON", "FACE", "HEAD"];

      for (var item in list) {
        final label = item['label'].toString().toUpperCase();
        final List<num> box = List<num>.from(item['box_2d']);
        final rect = Rect.fromLTRB(box[0]/1000, box[1]/1000, box[2]/1000, box[3]/1000);

        if (rect.width * rect.height > 0.95) continue;

        candidates.add(DetectionCandidate(
          objectLabel: label,
          relativeLocation: rect,
          isLiving: livingWords.any((w) => label.contains(w)),
          situation: IntentEngine.decode(label), // BINDING TO INTENT ENGINE
        ));
      }
      return candidates;
    } catch (e) { return []; }
  }

  void stop() => _isRunning = false;
}