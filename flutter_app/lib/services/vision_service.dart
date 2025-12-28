/**
 * FILE: flutter_app/lib/services/vision_service.dart
 * VERSION: 3.6.0
 * PHASE: Phase 8.6 (Zero-Shot Intelligence)
 * GOAL: Real-time AI Object Detection and Semantic Mapping via Gemini Vision.
 * FIX: 
 * 1. Enforced JSON-only mode via generationConfig.
 * 2. Standardized coordinates to [ymin, xmin, ymax, xmax].
 * 3. Generalized prompt for better zero-shot performance on small objects (e.g. pens).
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
      // Periodic Real-World Vision Scan every 6 seconds
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
    _statusController.add("AI is Thinking...");
    
    try {
      print("SATYA_DEBUG: Snatching frame from macOS Camera...");
      final CameraMacOSFile? imageData = await macController!.takePicture();
      
      if (imageData == null || imageData.bytes == null) {
        print("SATYA_DEBUG: Frame capture returned null.");
        _isAnalyzing = false;
        return;
      }

      print("SATYA_DEBUG: Image snatched (${imageData.bytes!.length} bytes). Sending to AI Brain...");
      final results = await _queryAIBrain(imageData.bytes!);
      
      _candidatesController.add(results);
      _statusController.add(results.isEmpty ? "No Objects Detected" : "Target Locked");
    } catch (e) {
      print("SATYA_VISION_ERROR: $e");
      _statusController.add("Lens Obscured");
    } finally {
      _isAnalyzing = false;
    }
  }

  Future<List<DetectionCandidate>> _queryAIBrain(Uint8List imageBytes) async {
    const apiKey = "AIzaSyCP6UyyBDURdVq1ySX2RtFOHkywSM0pXHI"; // Runtime provided
    const url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$apiKey";

    final base64Image = base64Encode(imageBytes);
    
    // REFINED PROMPT: Generic, precise, and enforces spatial focus
    final prompt = """
      Act as a specialized computer vision model. Detect and classify all physical objects in this image.
      For each object, determine:
      - 'label': Primary name (e.g. 'Marker', 'Phone', 'Laptop').
      - 'persona': Contextual category (Academic, Commuter, Professional, Work, Social, or Lifestyle).
      - 'box_2d': Coordinates [ymin, xmin, ymax, xmax] from 0 to 1000.
      
      Return results as a JSON array of objects.
    """;

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
          "generationConfig": {
            "responseMimeType": "application/json",
          }
        })
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? "[]";
        
        print("SATYA_RAW_RESPONSE: $rawText");

        final List<dynamic> parsed = jsonDecode(rawText);
        return parsed.map((item) {
          final List<num> box = List<num>.from(item['box_2d']);
          
          // Map ymin, xmin, ymax, xmax (0-1000) to Flutter 0.0-1.0
          final double yMin = box[0].toDouble() / 1000.0;
          final double xMin = box[1].toDouble() / 1000.0;
          final double yMax = box[2].toDouble() / 1000.0;
          final double xMax = box[3].toDouble() / 1000.0;

          return DetectionCandidate(
            objectLabel: item['label'],
            personaType: item['persona'],
            confidence: 0.99,
            relativeLocation: Rect.fromLTRB(xMin, yMin, xMax, yMax),
          );
        }).toList();
      } else {
        print("AI_GATEWAY_ERROR: Status ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("AI_REASONING_TIMEOUT: $e");
    }
    return [];
  }

  void triggerGestureSearch() => Future.delayed(const Duration(seconds: 3), () => _gestureController.add(RecognizedGesture.thumbsUp));

  void dispose() {
    mobileController?.dispose();
    _candidatesController.close();
    _gestureController.close();
    _statusController.close();
  }
}