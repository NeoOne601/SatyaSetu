/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 69.0.0
 * PHASE: Phase 76.4 (Stability Protocol)
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: 
 * 1. Hardware-Handover: Vision stream EXPLICITLY stops when a card is tapped.
 * 2. Async Planning: Cards fetch APE plans only when opened.
 * 3. Zero-Freeze UI: Separated eye (Florence) from brain (Gemma).
 */

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
    // 1. LOCK THE EYES: Free GPU memory for the brain
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
                
                const Row(children: [Icon(LucideIcons.listChecks, size: 14, color: Colors.blueAccent), SizedBox(width: 8), Text("AFFORDANCE ACTION CHAINS", style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.blueAccent))]),
                const SizedBox(height: 16),

                // 2. FETCH PLAN ON DEMAND: High Stability Path
                FutureBuilder<ApeResponse>(
                  future: IntentEngine.fetchAffordances(candidate.objectLabel, "general"),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const ListTile(title: Text("Synthesizing actions...", style: TextStyle(fontSize: 12, color: Colors.white38)));
                    
                    final plan = snapshot.data!;
                    if (plan.affordances.isEmpty) return const ListTile(title: Text("No actions available.", style: TextStyle(fontSize: 12, color: Colors.white38)));

                    return Column(
                      children: plan.affordances.map((aff) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(aff.name.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          children: aff.actions.map((act) => ListTile(
                            dense: true,
                            leading: CircleAvatar(radius: 10, backgroundColor: Colors.white10, child: Text("${act.step}", style: const TextStyle(fontSize: 9))),
                            title: Text(act.instruction, style: const TextStyle(fontSize: 11)),
                            trailing: act.recordable ? const Icon(LucideIcons.fingerprint, size: 14, color: Color(0xFF00FFC8)) : null,
                            onTap: () { Navigator.pop(c); _harvest(candidate, "Step ${act.step}: ${act.instruction}"); },
                          )).toList(),
                        ),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // 3. UNLOCK THE EYES: Resume real-time tracking
      widget.visionService.isPaused = false;
    });
  }

  void _harvest(DetectionCandidate c, String interaction) async {
    await IntentHarvester.harvest(widget.repo, c.objectLabel, SituationContext.global, "APE Result: $interaction", 10);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action recorded to ledger."), backgroundColor: Color(0xFF00FFC8), duration: Duration(milliseconds: 800)));
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
            const Text("APE HUB READY", style: TextStyle(fontSize: 8, color: Colors.white38)),
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