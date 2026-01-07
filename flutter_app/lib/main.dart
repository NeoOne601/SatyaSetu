/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 61.0.0
 * AUTHOR: SatyaSetu Neural Architect
 * FIX:
 * 1. Rendering: Wrapped modal in scrollable view with BoxConstraints.
 * 2. Interaction: Pauses vision stream during reasoning to protect VRAM.
 * 3. Contract: Implements the "2+3" choice logic via the APE engine.
 */

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera_macos/camera_macos.dart';
import 'services/vault_service.dart';
import 'services/vision_service.dart';
import 'services/hardware_id_service.dart';
import 'services/intent_harvester.dart';
import 'services/intent_engine.dart';
import 'services/mission_control_service.dart'; 
import 'identity_repo.dart';
import 'models/intent_models.dart';
import 'models/telemetry_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SatyaApp(
    vaultService: VaultService(IdentityRepository()), 
    repo: IdentityRepository(), 
    visionService: VisionService()
  ));
}

class SatyaApp extends StatelessWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  const SatyaApp({super.key, required this.vaultService, required this.repo, required this.visionService});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, 
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00FFC8), brightness: Brightness.dark)), 
    home: UnlockScreen(vaultService: vaultService, repo: repo, visionService: visionService)
  );
}

class UnlockScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  const UnlockScreen({super.key, required this.vaultService, required this.repo, required this.visionService});
  @override State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    setState(() => _isLoading = true);
    final hwId = await HardwareIdService.getDeviceId(); 
    final dir = await getApplicationSupportDirectory();
    final ok = await widget.vaultService.unlock(_pinController.text, hwId, dir.path);
    if (ok && mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo, visionService: widget.visionService)));
    else setState(() => _isLoading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
    const SizedBox(height: 32),
    SizedBox(width: 200, child: TextField(controller: _pinController, obscureText: true, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: "PIN"), keyboardType: TextInputType.number, onChanged: (v) { if (v.length == 6) _attemptUnlock(); })),
  ])));
}

class HomeScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  const HomeScreen({super.key, required this.vaultService, required this.repo, required this.visionService});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DetectionCandidate> _candidates = [];
  
  @override void initState() {
    super.initState();
    widget.visionService.initialize();
    widget.visionService.candidatesStream.listen((c) { if (mounted) setState(() => _candidates = c); });
  }

  void _showIntentCard(DetectionCandidate candidate) {
    // 1. TIER 1 CHOICES: INSTANT (Heuristic Engine)
    final instantState = IntentEngine.resolveInstant(candidate.objectLabel);
    
    // IQ 310: PAUSE VISION DURING REASONING
    widget.visionService.isPaused = true;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(candidate.objectLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const Divider(height: 32, color: Colors.white10),
                
                // Tier 1: 2 Florence Choices (Instant)
                ...instantState.actions.map((a) => ListTile(
                  dense: true,
                  leading: Icon(a.icon, color: instantState.themeColor, size: 20),
                  title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(a.description, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  onTap: () { Navigator.pop(c); _harvestInteraction(candidate, a.label); },
                )),
                
                const SizedBox(height: 20),
                const Row(children: [Icon(LucideIcons.brainCircuit, size: 14, color: Colors.blueAccent), SizedBox(width: 8), Text("GEMMA INQUIRIES (ADVANCED)", style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.blueAccent))]),
                const SizedBox(height: 12),

                // Tier 2: 3 Gemma Choices (Async)
                Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  child: FutureBuilder<List<String>>(
                    future: IntentEngine.fetchInquiries(candidate.objectLabel),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const ListTile(title: Text("Synthesizing context...", style: TextStyle(fontSize: 12, color: Colors.white38)));
                      return Column(
                        children: snapshot.data!.map((q) => ListTile(
                          dense: true,
                          title: Text(q, style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(LucideIcons.zap, size: 12, color: Colors.blueAccent),
                          onTap: () {
                            Navigator.pop(c);
                            _harvestInteraction(candidate, q);
                          },
                        )).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // IQ 310: RESUME VISION HEARTBEAT
      widget.visionService.isPaused = false;
    });
  }

  void _harvestInteraction(DetectionCandidate c, String decision) async {
    await IntentHarvester.harvest(widget.repo, c.objectLabel, SituationContext.global, "Trust Decision: $decision", 10);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trust interaction recorded to ledger."), backgroundColor: Color(0xFF00FFC8), duration: Duration(milliseconds: 800)));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          Positioned.fill(child: Opacity(opacity: 0.5, child: CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.attachCamera(c)))),
          ..._candidates.map((c) => _buildMorphicTile(c, constraints.maxWidth, constraints.maxHeight)),
          Positioned(top: 60, left: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("SATYA SETU", style: TextStyle(letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00FFC8))),
            Text(MissionControlService().totalDetections > 0 ? "PRIVATE HUB ACTIVE" : "SYNCHRONIZING...", style: const TextStyle(fontSize: 8, color: Colors.white38)),
          ])),
        ]);
      }),
    );
  }

  Widget _buildMorphicTile(DetectionCandidate c, double screenW, double screenH) {
    final Color baseColor = IntentEngine.generateVibrantColor(c.objectLabel);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: (c.relativeLocation.left * screenW).clamp(0, screenW - 50),
      top: (c.relativeLocation.top * screenH).clamp(0, screenH - 50),
      width: (c.relativeLocation.width * screenW).clamp(45.0, screenW),
      height: (c.relativeLocation.height * screenH).clamp(35.0, screenH),
      child: GestureDetector(
        onTap: () => _showIntentCard(c),
        child: Container(
          decoration: BoxDecoration(color: baseColor.withOpacity(0.1), border: Border.all(color: baseColor.withOpacity(0.8), width: 1.0), borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4), decoration: BoxDecoration(color: baseColor.withOpacity(0.85), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6))), child: Center(child: Text(c.objectLabel, style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black), overflow: TextOverflow.ellipsis)))]),
        ),
      ),
    );
  }
}