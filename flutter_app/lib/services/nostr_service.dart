/**
 * FILE: flutter_app/lib/services/nostr_service.dart
 * VERSION: 1.0.0
 * PHASE: Phase 13 (Nostr Protocol Integration)
 * DESCRIPTION: 
 * High-level service for Nostr operations.
 * Wraps Rust FFI with Flutter-friendly interfaces for event signing, 
 * broadcasting, and subscription.
 */

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../identity_repo.dart';
import 'database_service.dart';
import 'event_bus.dart';

/// Nostr Event Kinds for Satya Setu protocol
class NostrEventKind {
  static const int textNote = 1;
  static const int review = 1985;      // User reviews/verifications
  static const int ad = 1040;          // Vendor promotions
  static const int signedIntent = 29001; // Legacy signed intents
  static const int trustUpdate = 29002;  // Trust score updates
}

/// A Nostr event parsed from JSON
class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<dynamic> tags;
  final String content;
  final String sig;
  
  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
  });
  
  factory NostrEvent.fromJson(Map<String, dynamic> json) {
    return NostrEvent(
      id: json['id'] ?? '',
      pubkey: json['pubkey'] ?? '',
      createdAt: json['created_at'] ?? 0,
      kind: json['kind'] ?? 0,
      tags: json['tags'] ?? [],
      content: json['content'] ?? '',
      sig: json['sig'] ?? '',
    );
  }
  
  /// Get the DID from event tags
  String? get did {
    for (final tag in tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'did' && tag.length > 1) {
        return tag[1] as String?;
      }
    }
    return null;
  }
  
  /// Parse the content as JSON
  Map<String, dynamic>? get contentJson {
    try {
      return jsonDecode(content);
    } catch (e) {
      return null;
    }
  }
  
  /// Check if this is a review event
  bool get isReview => kind == NostrEventKind.review;
  
  /// Check if this is an ad event
  bool get isAd => kind == NostrEventKind.ad;
}

/// Service for Nostr protocol operations
class NostrService {
  static final NostrService _instance = NostrService._internal();
  factory NostrService() => _instance;
  NostrService._internal();
  
  final IdentityRepository _repo = IdentityRepository();
  final DatabaseService _db = DatabaseService();
  final EventBus _eventBus = EventBus();
  
  // Stream controller for received events
  final _eventsController = StreamController<NostrEvent>.broadcast();
  Stream<NostrEvent> get eventsStream => _eventsController.stream;
  
  /// Sign and broadcast a verification for an entity
  Future<bool> broadcastVerification({
    required String identityId,
    required String entityId,
    required String entityLabel,
    required double rating,
    String? comment,
  }) async {
    try {
      // Build verification payload
      final payload = {
        'type': 'verification',
        'entity_id': entityId,
        'entity_label': entityLabel,
        'rating': rating,
        'comment': comment,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Sign as Nostr event
      final signedEvent = await _repo.signEvent(
        identityId,
        NostrEventKind.review,
        jsonEncode(payload),
      );
      
      // Broadcast to relays
      final success = await _repo.broadcastEvent(signedEvent);
      
      if (success) {
        // Record locally
        await _db.recordInteraction(
          entityId: entityId,
          actionType: 'VERIFY',
          rating: (rating * 5).round(),
        );
        
        debugPrint('flutter: SATYA_DEBUG: [NOSTR] Verification broadcast for $entityLabel');
      }
      
      return success;
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [NOSTR] Verification failed: $e');
      return false;
    }
  }
  
  /// Sign and broadcast a report for an entity
  Future<bool> broadcastReport({
    required String identityId,
    required String entityId,
    required String entityLabel,
    required String reason,
  }) async {
    try {
      final payload = {
        'type': 'report',
        'entity_id': entityId,
        'entity_label': entityLabel,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final signedEvent = await _repo.signEvent(
        identityId,
        NostrEventKind.review,
        jsonEncode(payload),
      );
      
      final success = await _repo.broadcastEvent(signedEvent);
      
      if (success) {
        await _db.recordInteraction(
          entityId: entityId,
          actionType: 'REPORT',
        );
        
        debugPrint('flutter: SATYA_DEBUG: [NOSTR] Report broadcast for $entityLabel');
      }
      
      return success;
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [NOSTR] Report failed: $e');
      return false;
    }
  }
  
  /// Sign and broadcast a purchase intent
  Future<bool> broadcastPurchaseIntent({
    required String identityId,
    required String productId,
    required String vendorDid,
    required int amountInr,
  }) async {
    try {
      final payload = {
        'type': 'purchase_intent',
        'product_id': productId,
        'vendor_did': vendorDid,
        'amount_inr': amountInr,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final signedEvent = await _repo.signEvent(
        identityId,
        NostrEventKind.signedIntent,
        jsonEncode(payload),
      );
      
      final success = await _repo.broadcastEvent(signedEvent);
      
      if (success) {
        debugPrint('flutter: SATYA_DEBUG: [NOSTR] Purchase intent broadcast: ₹$amountInr');
      }
      
      return success;
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [NOSTR] Purchase intent failed: $e');
      return false;
    }
  }
  
  /// Fetch reviews for an entity from the network
  Future<List<NostrEvent>> fetchReviewsForEntity(String entityId) async {
    try {
      // Subscribe to review events
      final eventJsons = await _repo.subscribeEvents(
        [NostrEventKind.review],
        limit: 50,
      );
      
      // Parse and filter for this entity
      final events = <NostrEvent>[];
      for (final json in eventJsons) {
        try {
          final event = NostrEvent.fromJson(jsonDecode(json));
          final content = event.contentJson;
          if (content != null && content['entity_id'] == entityId) {
            events.add(event);
            _eventsController.add(event);
          }
        } catch (e) {
          // Skip malformed events
        }
      }
      
      debugPrint('flutter: SATYA_DEBUG: [NOSTR] Found ${events.length} reviews for entity');
      return events;
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [NOSTR] Fetch reviews failed: $e');
      return [];
    }
  }
  
  /// Fetch all recent trust updates from the network
  Future<List<NostrEvent>> fetchRecentTrustUpdates({int limit = 100}) async {
    try {
      final eventJsons = await _repo.subscribeEvents(
        [NostrEventKind.review, NostrEventKind.trustUpdate],
        limit: limit,
      );
      
      final events = <NostrEvent>[];
      for (final json in eventJsons) {
        try {
          final event = NostrEvent.fromJson(jsonDecode(json));
          events.add(event);
          _eventsController.add(event);
        } catch (e) {
          // Skip malformed events
        }
      }
      
      debugPrint('flutter: SATYA_DEBUG: [NOSTR] Fetched ${events.length} trust updates');
      return events;
    } catch (e) {
      debugPrint('flutter: SATYA_DEBUG: [NOSTR] Fetch trust updates failed: $e');
      return [];
    }
  }
  
  /// Dispose resources
  void dispose() {
    _eventsController.close();
  }
}
