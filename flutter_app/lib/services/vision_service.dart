/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 3.9.1
 * PHASE: Phase 9.0 (Zero-Shot Reality)
 * FIX: Incorporated 30s timeout and optimized detection prompt.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class DetectionCandidate {
  final String objectLabel;
  final String personaType;
  final double confidence;
  final Rect relativeLocation; 
  
  DetectionCandidate({
    required this.objectLabel, 
    required this.personaType, 
    required this.confidence,
    required this.relativeLocation,
  });
}

enum RecognizedGesture { none, thumbsUp }

class VisionService {
  CameraController? mobileController;
  CameraMacOSController? macController; 
  bool _isAnalyzing = false;
  
  final _candidatesController = StreamController<List<DetectionCandidate>>.broadcast();
  final _gestureController = StreamController<RecognizedGesture>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  
  Stream<List<DetectionCandidate>> get candidatesStream => _candidatesController.stream;
  Stream<RecognizedGesture> get gestureStream => _gestureController.stream;
  Stream<String> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    if (Platform.isMacOS) {
      Timer.periodic(const Duration(seconds: 6), (timer) {
        if (!_isAnalyzing && macController != null) {
          _performRealWorldAnalysis();
        }
      });
    } else {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) return;
        mobileController = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
        await mobileController!.initialize();
      } catch (e) { print("MOBILE_VISION_ERR: $e"); }
    }
  }

  Future<void> _performRealWorldAnalysis() async {
    if (_isAnalyzing) return;
    _isAnalyzing = true;
    _statusController.add("AI Thinking...");
    try {
      final CameraMacOSFile? imageData = await macController!.takePicture();
      if (imageData == null || imageData.bytes == null) {
        _isAnalyzing = false;
        return;
      }
      final results = await _queryAIBrain(imageData.bytes!);
      _candidatesController.add(results);
      _statusController.add(results.isEmpty ? "Scanning..." : "Target Locked");
    } catch (e) {
      _statusController.add("Lens Muffled");
    } finally {
      _isAnalyzing = false;
    }
  }

  Future<List<DetectionCandidate>> _queryAIBrain(Uint8List imageBytes) async {
    const apiKey = "YOUR_API_KEY"; 
    const url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$apiKey";
    final base64Image = base64Encode(imageBytes);
    
    // REFINED PROMPT: Uses generic expert context for higher zero-shot accuracy
    const prompt = "Act as a Computer Vision Assistant. Detect objects. Return ONLY a JSON array of objects with 'label', 'persona' (Academic, Commuter, Professional, Work, Social, or Lifestyle), and 'box_2d' [ymin, xmin, ymax, xmax] (0-1000).";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [
              {"text": prompt},
              {"inlineData": {"mimeType": "image/png", "data": base64Image}}
            ]
          }],
          "generationConfig": {"responseMimeType": "application/json"}
        })
      ).timeout(const Duration(seconds: 30)); 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? "[]";
        final List<dynamic> parsed = jsonDecode(rawText);
        return parsed.map((item) {
          final box = List<num>.from(item['box_2d']);
          return DetectionCandidate(
            objectLabel: item['label'],
            personaType: item['persona'],
            confidence: 0.99,
            relativeLocation: Rect.fromLTRB(
              box[1].toDouble() / 1000.0, box[0].toDouble() / 1000.0, 
              box[3].toDouble() / 1000.0, box[2].toDouble() / 1000.0
            ),
          );
        }).toList();
      }
    } catch (e) { print("AI_VISION_LATENCY: $e"); }
    return [];
  }

  void triggerGestureSearch() => Future.delayed(const Duration(seconds: 3), () => _gestureController.add(RecognizedGesture.thumbsUp));
}