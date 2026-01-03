/**
 * FILE: flutter_app/lib/screens/mission_control_screen.dart
 * VERSION: 1.0.0
 * PHASE: Phase 51.2 (The Command Center)
 * AUTHOR: SatyaSetu Mission Systems
 * DESCRIPTION: The Admin Dashboard visualizing the Satya Objective.
 */

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/mission_control_service.dart';
import '../models/telemetry_models.dart';

class MissionControlScreen extends StatelessWidget {
  const MissionControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("MISSION CONTROL", style: TextStyle(letterSpacing: 4, fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<SystemHealth>(
        stream: MissionControlService().statsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Text("Waiting for Neural Heartbeat..."));
          
          final health = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard("BRAIN LATENCY", "${health.averageLatency.toStringAsFixed(2)}s", LucideIcons.activity, Colors.blueAccent),
                _buildStatCard("PULSE COUNT", "${health.totalDetections}", LucideIcons.zap, const Color(0xFF00FFC8)),
                _buildStatCard("ERROR RATE", "${health.errorPercentage.toStringAsFixed(1)}%", LucideIcons.alertTriangle, Colors.redAccent),
                _buildStatCard("UPTIME", "100%", LucideIcons.shieldCheck, Colors.purpleAccent),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 10, color: color, letterSpacing: 1, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}