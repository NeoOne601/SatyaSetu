/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 4.3.0
 * PHASE: Phase 9.2 (Hybrid Intelligence)
 * GOAL: Dynamic Gemini -> Ollama Fallback with exhaustive logging.
 * FIX: Integrated local Gemma 3 support and user-validated 30s timeouts.
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
      debugPrint("flutter: SATYA_DEBUG: [VISION] Booting macOS Lens Loop (Hybrid Mode)...");
      Timer.periodic(const Duration(seconds: 8), (timer) {
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
      } catch (e) { debugPrint("flutter: SATYA_DEBUG: [VISION] Mobile Camera Init Error: $e"); }
    }
  }

  Future<void> _performRealWorldAnalysis() async {
    if (_isAnalyzing) return;
    _isAnalyzing = true;
    _statusController.add("AI Analysis in Progress...");
    
    try {
      final CameraMacOSFile? imageData = await macController!.takePicture();
      if (imageData == null || imageData.bytes == null) {
        debugPrint("flutter: SATYA_DEBUG: [VISION] Frame capture returned null.");
        _isAnalyzing = false;
        return;
      }

      debugPrint("flutter: SATYA_DEBUG: [VISION] Frame snatched (${imageData.bytes!.length} bytes). Engaging Hybrid Brain.");
      final results = await _queryHybridBrain(imageData.bytes!);
      _candidatesController.add(results);
      _statusController.add(results.isEmpty ? "No Object Detected" : "Target Locked");
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Fatal analysis failure: $e");
      _statusController.add("Lens Obscured");
    } finally {
      _isAnalyzing = false;
    }
  }

  /// THE HYBRID COORDINATOR: Switches between Cloud (Gemini) and Local (Ollama)
  Future<List<DetectionCandidate>> _queryHybridBrain(Uint8List imageBytes) async {
    try {
      // 1. Attempt Cloud Analysis (Gemini)
      return await _queryGemini(imageBytes);
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Gemini Unavailable/Limited. Shifting to Local Ollama...");
      _statusController.add("Local Brain Active");
      return await _queryOllama(imageBytes);
    }
  }

  Future<List<DetectionCandidate>> _queryGemini(Uint8List imageBytes) async {
    const apiKey = "YOUR_API_KEY_HERE"; // Ensure key is set locally
    if (apiKey == "YOUR_API_KEY_HERE") throw Exception("No Gemini Key");

    const url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$apiKey";
    final base64Image = base64Encode(imageBytes);
    const prompt = "Act as a Computer Vision Expert. Detect primary physical objects. Return ONLY a raw JSON array of objects with keys 'label', 'persona' (Academic, Commuter, Professional, Work, Social, or Lifestyle), and 'box_2d' [ymin, xmin, ymax, xmax] (0-1000).";

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [{"parts": [{"text": prompt}, {"inlineData": {"mimeType": "image/png", "data": base64Image}}]}]
      })
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Gemini Analysis Successful.");
      final text = jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'];
      return _parseJson(text);
    }
    throw Exception("Gemini Status: ${response.statusCode}");
  }

  /// OLLAMA BRAIN: Communicates with your local gemma3 instance
  Future<List<DetectionCandidate>> _queryOllama(Uint8List imageBytes) async {
    const url = "http://localhost:11434/api/generate";
    final base64Image = base64Encode(imageBytes);
    const prompt = "Identify physical objects in this image. For each, give a one-word label, a persona category (Academic, Commuter, Professional, Work, Social, or Lifestyle), and a normalized bounding box [ymin, xmin, ymax, xmax] from 0 to 1000. Return ONLY as a JSON array.";

    try {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Calling Local Ollama (Gemma 3)...");
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode({
          "model": "gemma3:27b", 
          "prompt": prompt,
          "images": [base64Image],
          "stream": false,
          "format": "json"
        })
      ).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        debugPrint("flutter: SATYA_DEBUG: [VISION] Local Ollama Analysis Successful.");
        final data = jsonDecode(response.body);
        return _parseJson(data['response']);
      }
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] Local Ollama Brain Unreachable: $e");
    }
    return [];
  }

  List<DetectionCandidate> _parseJson(String rawText) {
    try {
      final cleaned = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> parsed = jsonDecode(cleaned);
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
    } catch (e) {
      debugPrint("flutter: SATYA_DEBUG: [VISION] JSON Structural mismatch or empty response.");
      return [];
    }
  }

  void triggerGestureSearch() => Future.delayed(const Duration(seconds: 3), () => _gestureController.add(RecognizedGesture.thumbsUp));
}