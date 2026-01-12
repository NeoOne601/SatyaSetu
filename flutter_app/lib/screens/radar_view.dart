/**
 * FILE: flutter_app/lib/screens/radar_view.dart
 * VERSION: 1.0.0
 * PHASE: Phase 10.2
 * DESCRIPTION: Visualizes the "Trust Air" using a scanning radar UI.
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/discovery_service.dart';

class RadarView extends StatefulWidget {
  final DiscoveryService discoveryService;
  const RadarView({super.key, required this.discoveryService});

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<DiscoveryNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    widget.discoveryService.radarPulse.listen((nodes) {
      if (mounted) setState(() => _nodes = nodes);
    });
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
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: RadarScannerPainter(_controller.value),
                size: const Size(200, 200),
              );
            },
          ),
          ..._nodes.map((node) => _buildBlip(node)),
          Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00FFC8), shape: BoxShape.circle))),
        ],
      ),
    );
  }

  Widget _buildBlip(DiscoveryNode node) {
    final normalizedDist = ((node.rssi.clamp(-90, -20) + 90) / 70); 
    final distance = 1.0 - normalizedDist;
    final angle = (node.id.hashCode % 360) * (math.pi / 180);
    
    final radius = 90.0 * distance;
    final x = 100 + radius * math.cos(angle);
    final y = 100 + radius * math.sin(angle);

    return Positioned(
      left: x - 6,
      top: y - 6,
      child: Tooltip(
        message: "${node.sector.toUpperCase()}\nKarma: ${node.karmaScore.toStringAsFixed(1)}",
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getSectorColor(node.sector).withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _getSectorColor(node.sector), blurRadius: 6)],
          ),
        ),
      ),
    );
  }

  Color _getSectorColor(String sector) {
    switch (sector) {
      case 'transport': return Colors.blueAccent;
      case 'trade': return Colors.amber;
      case 'civic': return Colors.purpleAccent;
      default: return Colors.white;
    }
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