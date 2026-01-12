/**
 * FILE: flutter_app/lib/screens/heatmap_view.dart
 * VERSION: 1.0.0
 * PHASE: Phase 10.2
 * DESCRIPTION: Visualizes Signal Density (S2 Cell Trust) on a map simulation.
 */

import 'package:flutter/material.dart';

class HeatmapView extends StatelessWidget {
  const HeatmapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: S2GridPainter(),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
              child: const Row(
                children: [
                  Icon(Icons.public, color: Color(0xFF00FFC8), size: 16),
                  SizedBox(width: 8),
                  Text("S2 CELL: 887192", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class S2GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.white10;
    final heatPaint = Paint()..style = PaintingStyle.fill;

    double step = 80.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    heatPaint.color = Colors.blueAccent.withOpacity(0.2);
    canvas.drawRect(Rect.fromLTWH(step * 2, step * 3, step, step), heatPaint);
    
    heatPaint.color = Colors.amber.withOpacity(0.15);
    canvas.drawRect(Rect.fromLTWH(step * 3, step * 3, step, step), heatPaint);

    heatPaint.color = const Color(0xFF00FFC8).withOpacity(0.3); 
    canvas.drawRect(Rect.fromLTWH(step * 2, step * 2, step, step), heatPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}