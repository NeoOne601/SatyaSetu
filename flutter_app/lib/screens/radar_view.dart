/**
 * FILE: flutter_app/lib/screens/radar_view.dart
 * VERSION: 1.1.0
 * PHASE: Phase 10.3
 * DESCRIPTION: Visualizes camera detection candidates as blips on a radar.
 * CHANGE: Updated to accept DetectionCandidate list from VisionService.
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/vision_service.dart'; // Changed import to use detection candidates

class RadarView extends StatefulWidget {
  // CHANGED: Now accepts visual candidates instead of discovery service
  final List<DetectionCandidate> candidates;
  
  const RadarView({super.key, required this.candidates});

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.4),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          // The spinning sweep animation
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: RadarScannerPainter(_controller.value),
                size: const Size(200, 200),
              );
            },
          ),
          // The visual blips
          ...widget.candidates.map((c) => _buildVisualBlip(c)),
          // The center point (User)
          Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00FFC8), shape: BoxShape.circle))),
        ],
      ),
    );
  }

  Widget _buildVisualBlip(DetectionCandidate candidate) {
    // Map the relative location (0.0 to 1.0) to radar coordinates
    // We map X (horizontal) to Angle, and Y (distance) to Radius for a cool effect
    
    // Center of radar is 50, 50 (relative to 100x100 container internal size logic)
    // But since this is inside a Stack, we use pixel offsets.
    
    // Simple Mapping:
    // Left/Right on screen -> Angle on Radar
    // Top/Bottom on screen -> Distance on Radar
    
    // Normalize X from 0..1 to -PI/4 .. PI/4 (Front cone view)
    final double angle = (candidate.relativeLocation.center.dx - 0.5) * (math.pi / 2);
    
    // Normalize Y (distance): Bottom of screen is close (0), Top is far (1)
    // But usually in camera AR, Top is "Far" and Bottom is "Close".
    // Let's invert Y so 1.0 (bottom) is close (center of radar)
    final double distance = (1.0 - candidate.relativeLocation.center.dy).clamp(0.1, 0.9);
    
    final double radius = distance * 90.0; // 90 is radius of radar content
    
    final double x = 100 + radius * math.sin(angle);
    final double y = 100 - radius * math.cos(angle);

    return Positioned(
      left: x - 4,
      top: y - 4,
      child: Tooltip(
        message: candidate.objectLabel,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF00FFC8).withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0xFF00FFC8), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

class RadarScannerPainter extends CustomPainter {
  final double angle;
  RadarScannerPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [Colors.transparent, const Color(0xFF00FFC8).withOpacity(0.2)],
        stops: const [0.8, 1.0],
        transform: GradientRotation((angle * math.pi * 2) - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(RadarScannerPainter oldDelegate) => angle != oldDelegate.angle;
}