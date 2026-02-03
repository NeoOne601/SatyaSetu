/**
 * FILE: flutter_app/lib/services/event_bus.dart
 * VERSION: 1.0.0
 * PHASE: Phase 12 (Sovereign Commerce)
 * DESCRIPTION: 
 * Simple pub/sub event bus using StreamController.
 * Decouples vision from commerce - camera continues scanning while commerce engine queries asynchronously.
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'vision_service.dart';

/// Event types for the Satya Setu event bus
enum SatyaEventType {
  // Vision Events
  objectSelected,       // User tapped a detected object
  objectLongPressed,    // User long-pressed an object
  detectionUpdated,     // New detections available
  
  // Drawer Events  
  drawerOpened,         // Sovereign Drawer opened
  drawerClosed,         // Sovereign Drawer closed
  drawerExpanded,       // Drawer expanded to 90%
  drawerCollapsed,      // Drawer collapsed to 40%
  
  // Commerce Events
  productsFetched,      // Products loaded from cache/network
  productSelected,      // User selected a product
  bountySelected,       // User selected a bounty
  
  // Interaction Events
  verifyAction,         // User clicked "Verify"
  reportAction,         // User clicked "Report"
  buyAction,            // User clicked "Buy"
  rateAction,           // User rated an entity
}

/// Event payload for type-safe event handling
class SatyaEvent {
  final SatyaEventType type;
  final dynamic payload;
  final DateTime timestamp;
  
  SatyaEvent({
    required this.type,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  /// Helper to check if this event has a specific payload type
  bool hasPayload<T>() => payload is T;
  
  /// Helper to get typed payload
  T? getPayload<T>() => payload is T ? payload as T : null;
}

/// Event payload when an object is selected
class ObjectSelectedPayload {
  final DetectionCandidate candidate;
  final Offset screenPosition;
  
  ObjectSelectedPayload({
    required this.candidate,
    required this.screenPosition,
  });
}

/// Event payload for drawer state changes
class DrawerStatePayload {
  final double extent;        // Current extent (0.0 - 1.0)
  final bool isAnimating;     // Whether transitioning
  final String? objectLabel;  // Currently selected object
  
  DrawerStatePayload({
    required this.extent,
    this.isAnimating = false,
    this.objectLabel,
  });
}

/// Singleton Event Bus for decoupled communication
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();
  
  final _controller = StreamController<SatyaEvent>.broadcast();
  
  /// Stream of all events
  Stream<SatyaEvent> get events => _controller.stream;
  
  /// Stream filtered by event type
  Stream<SatyaEvent> on(SatyaEventType type) {
    return _controller.stream.where((event) => event.type == type);
  }
  
  /// Stream filtered by multiple event types
  Stream<SatyaEvent> onAny(List<SatyaEventType> types) {
    return _controller.stream.where((event) => types.contains(event.type));
  }
  
  /// Emit an event to all listeners
  void emit(SatyaEventType type, [dynamic payload]) {
    final event = SatyaEvent(type: type, payload: payload);
    _controller.add(event);
    debugPrint('flutter: SATYA_DEBUG: [EVENT_BUS] Emitted: ${type.name}');
  }
  
  /// Emit an object selected event
  void emitObjectSelected(DetectionCandidate candidate, Offset screenPosition) {
    emit(
      SatyaEventType.objectSelected,
      ObjectSelectedPayload(candidate: candidate, screenPosition: screenPosition),
    );
  }
  
  /// Emit a drawer state change event
  void emitDrawerState(SatyaEventType type, double extent, {String? objectLabel}) {
    emit(
      type,
      DrawerStatePayload(extent: extent, objectLabel: objectLabel),
    );
  }
  
  /// Subscribe to object selection events
  StreamSubscription<SatyaEvent> onObjectSelected(
    void Function(DetectionCandidate candidate, Offset position) callback,
  ) {
    return on(SatyaEventType.objectSelected).listen((event) {
      final payload = event.getPayload<ObjectSelectedPayload>();
      if (payload != null) {
        callback(payload.candidate, payload.screenPosition);
      }
    });
  }
  
  /// Subscribe to drawer events
  StreamSubscription<SatyaEvent> onDrawer(
    void Function(SatyaEventType type, DrawerStatePayload? state) callback,
  ) {
    return onAny([
      SatyaEventType.drawerOpened,
      SatyaEventType.drawerClosed,
      SatyaEventType.drawerExpanded,
      SatyaEventType.drawerCollapsed,
    ]).listen((event) {
      callback(event.type, event.getPayload<DrawerStatePayload>());
    });
  }
  
  /// Dispose the event bus
  void dispose() {
    _controller.close();
  }
}
