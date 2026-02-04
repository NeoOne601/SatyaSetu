/**
 * FILE: flutter_app/lib/services/semantic_matcher.dart
 * VERSION: 1.0.0
 * DESCRIPTION: Semantic category matching using pre-computed embeddings.
 * - Loads category embeddings from assets
 * - Matches unknown labels to nearest category
 * - Falls back to keyword matching for quick hits
 */

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of semantic matching
class SemanticMatchResult {
  final String category;
  final double confidence;
  
  SemanticMatchResult({required this.category, required this.confidence});
  
  @override
  String toString() => 'SemanticMatchResult($category, confidence: ${confidence.toStringAsFixed(3)})';
}

/// Semantic category matcher using pre-computed embeddings
class SemanticMatcher {
  static SemanticMatcher? _instance;
  static SemanticMatcher get instance => _instance ??= SemanticMatcher._();
  
  SemanticMatcher._();
  
  bool _initialized = false;
  Map<String, List<double>> _categoryEmbeddings = {};
  List<String> _categories = [];
  int _dimensions = 384;
  
  /// Keywords for fast matching (avoids embedding computation)
  static const Map<String, List<String>> _keywordHints = {
    "COMPUTER": ["macbook", "thinkpad", "laptop", "desktop", "pc", "computer", "workstation"],
    "PHONE": ["iphone", "android", "smartphone", "mobile", "phone", "galaxy", "pixel"],
    "TABLET": ["ipad", "kindle", "tablet", "e-reader", "surface"],
    "FOOTWEAR": ["nike", "adidas", "shoe", "sneaker", "boot", "trainer", "sandal"],
    "HEADPHONES": ["airpods", "headphone", "earbuds", "earphone", "beats", "sony wh"],
    "WATCH": ["watch", "apple watch", "smartwatch", "rolex", "casio", "fitbit"],
    "BAG": ["backpack", "bag", "purse", "luggage", "briefcase", "tote"],
    "GLASSES": ["glasses", "sunglasses", "spectacles", "eyewear", "ray-ban"],
    "CAMERA": ["canon", "nikon", "sony", "camera", "dslr", "gopro"],
    "BOOK": ["book", "novel", "textbook", "magazine", "journal"],
  };
  
  /// Initialize the matcher with pre-computed embeddings
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final jsonString = await rootBundle.loadString('assets/category_embeddings.min.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      _dimensions = data['dimensions'] as int;
      _categories = List<String>.from(data['categories'] as List);
      
      final embeddings = data['embeddings'] as Map<String, dynamic>;
      _categoryEmbeddings = embeddings.map((key, value) {
        return MapEntry(key, List<double>.from(value as List));
      });
      
      _initialized = true;
      debugPrint('SEMANTIC_MATCHER: Initialized with ${_categories.length} categories, $_dimensions dimensions');
    } catch (e) {
      debugPrint('SEMANTIC_MATCHER_ERROR: Failed to load embeddings: $e');
      _initialized = false;
    }
  }
  
  /// Match a label to the best category
  SemanticMatchResult matchCategory(String label, {double threshold = 0.5}) {
    if (!_initialized) {
      debugPrint('SEMANTIC_MATCHER: Not initialized, returning OBJECT');
      return SemanticMatchResult(category: 'OBJECT', confidence: 0.0);
    }
    
    final labelLower = label.toLowerCase();
    
    // Fast path: keyword hints
    final keywordMatch = _matchByKeywords(labelLower);
    if (keywordMatch != null) {
      debugPrint('SEMANTIC_MATCH_KEYWORD: $label → ${keywordMatch.category} (${keywordMatch.confidence})');
      return keywordMatch;
    }
    
    // Slow path: semantic similarity (embedding comparison)
    final semanticMatch = _matchByEmbeddings(labelLower, threshold);
    if (semanticMatch != null) {
      debugPrint('SEMANTIC_MATCH_EMBEDDING: $label → ${semanticMatch.category} (${semanticMatch.confidence})');
      return semanticMatch;
    }
    
    // Fallback
    return SemanticMatchResult(category: 'OBJECT', confidence: 0.0);
  }
  
  /// Fast keyword-based matching
  SemanticMatchResult? _matchByKeywords(String labelLower) {
    for (final entry in _keywordHints.entries) {
      for (final keyword in entry.value) {
        if (labelLower.contains(keyword)) {
          return SemanticMatchResult(category: entry.key, confidence: 0.9);
        }
      }
    }
    return null;
  }
  
  /// Embedding-based semantic matching
  SemanticMatchResult? _matchByEmbeddings(String labelLower, double threshold) {
    // Generate a simple embedding for the label based on character n-grams
    // This is a placeholder - in production, use actual word embeddings
    final labelEmbedding = _generateSimpleEmbedding(labelLower);
    
    String? bestCategory;
    double bestScore = 0.0;
    
    for (final entry in _categoryEmbeddings.entries) {
      final similarity = _cosineSimilarity(labelEmbedding, entry.value);
      if (similarity > bestScore && similarity >= threshold) {
        bestScore = similarity;
        bestCategory = entry.key;
      }
    }
    
    if (bestCategory != null) {
      return SemanticMatchResult(category: bestCategory, confidence: bestScore);
    }
    
    return null;
  }
  
  /// Generate a simple embedding for a label (character n-gram based)
  /// This is a placeholder for actual model inference
  List<double> _generateSimpleEmbedding(String text) {
    // Simple hash-based embedding for demonstration
    // In production, this would use TFLite or Rust model inference
    final embedding = List<double>.filled(_dimensions, 0.0);
    
    final chars = text.toLowerCase().codeUnits;
    for (int i = 0; i < chars.length; i++) {
      final idx = chars[i] % _dimensions;
      embedding[idx] += 1.0;
      
      // Bi-grams
      if (i < chars.length - 1) {
        final bigramIdx = (chars[i] * 31 + chars[i + 1]) % _dimensions;
        embedding[bigramIdx] += 0.5;
      }
    }
    
    // Normalize
    final norm = math.sqrt(embedding.fold<double>(0.0, (sum, v) => sum + v * v));
    if (norm > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= norm;
      }
    }
    
    return embedding;
  }
  
  /// Cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0 || normB == 0) return 0.0;
    
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }
  
  /// Get all available categories
  List<String> get categories => List.unmodifiable(_categories);
  
  /// Check if initialized
  bool get isInitialized => _initialized;
  
  /// Get number of categories
  int get categoryCount => _categories.length;
}
