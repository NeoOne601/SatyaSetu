/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 37.0.0
 * PHASE: Phase 52.3 (Feedback & Trust Capture)
 * AUTHOR: SatyaSetu Neural Architect
 * DESCRIPTION: Implements two-stage interaction flow:
 * 1. Execute Intent Action.
 * 2. Rate AI Helpfulness (Trust Score) for harvest ledger.
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
import 'identity_repo.dart';
import 'models/intent_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = IdentityRepository();
  final vaultService = VaultService(repo);
  final visionService = VisionService();
  runApp(SatyaApp(vaultService: vaultService, repo: repo, visionService: visionService));
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
    final directory = await getApplicationSupportDirectory();
    final hwId = await HardwareIdService.getDeviceId(); 
    final ok = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo, visionService: widget.visionService)));
    } else {
      setState(() => _isLoading = false);
      _pinController.clear();
    }
  }

  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
    const SizedBox(height: 48),
    Container(constraints: const BoxConstraints(maxWidth: 300), child: TextField(controller: _pinController, obscureText: true, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: "••••••"), keyboardType: TextInputType.number, onChanged: (v) { if (v.length == 6) _attemptUnlock(); })),
    const SizedBox(height: 32),
    _isLoading ? const CircularProgressIndicator(color: Color(0xFF00FFC8)) : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity Vault"))
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
    widget.visionService.candidatesStream.listen((c) {
      if (mounted) setState(() => _candidates = c);
    });
  }

  void _showIntentCard(DetectionCandidate candidate) {
    if (candidate.situation == null) return;
    final state = candidate.situation!;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(state.title.toUpperCase(), style: TextStyle(letterSpacing: 2, fontSize: 10, color: state.themeColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(candidate.objectLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Divider(height: 40, color: Colors.white10),
            ...state.actions.map((action) => ListTile(
              onTap: () {
                Navigator.pop(c);
                _executeAndRate(candidate, action);
              },
              leading: Icon(action.icon, color: state.themeColor),
              title: Text(action.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(action.description, style: const TextStyle(fontSize: 10, color: Colors.white54)),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _executeAndRate(DetectionCandidate c, MorphicAction action) async {
    // 1. Initial notification
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Executing: ${action.label}"), backgroundColor: const Color(0xFF00FFC8)));

    // 2. Trust Score Collection
    int? score = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Trust Signal"),
        content: const Text("Was this AI prediction helpful? (1-5)"),
        actions: List.generate(5, (i) => TextButton(
          onPressed: () => Navigator.pop(ctx, i + 1),
          child: Text("${i + 1}"),
        )),
      ),
    );

    if (score != null) {
      // 3. Cryptographic Harvest
      await IntentHarvester.harvest(
        widget.repo, 
        c.objectLabel, 
        c.situation!.context, 
        action.label, 
        score
      );
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          Positioned.fill(child: Opacity(opacity: 0.5, child: CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.attachCamera(c)))),
          
          ..._candidates.map((c) => _buildMorphicTile(c, constraints.maxWidth, constraints.maxHeight)),
          
          const Positioned(top: 60, left: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("SATYA SETU", style: TextStyle(letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00FFC8))),
            Text("SPECTRAL SEMANTICS ACTIVE", style: TextStyle(fontSize: 8, color: Colors.white38)),
          ])),
        ]);
      }),
    );
  }

  Widget _buildMorphicTile(DetectionCandidate c, double screenW, double screenH) {
    // SPECTRAL COLORING: Use AI-selected color if available, fallback to Red/Green
    final Color baseColor = c.situation?.themeColor ?? (c.isLiving ? const Color(0xFFFF4545) : const Color(0xFF00FFC8));
    
    final double tileW = (c.relativeLocation.width * screenW).clamp(40.0, screenW);
    final double tileH = (c.relativeLocation.height * screenH).clamp(30.0, screenH);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: c.relativeLocation.left * screenW,
      top: c.relativeLocation.top * screenH,
      width: tileW,
      height: tileH,
      child: GestureDetector(
        onTap: () => _showIntentCard(c),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.1),
            border: Border.all(color: baseColor.withOpacity(0.8), width: 1.0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(color: baseColor.withOpacity(0.85), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(c.situation == null ? LucideIcons.loader2 : LucideIcons.zap, size: 7, color: Colors.black),
                    const SizedBox(width: 2),
                    Flexible(child: Text(
                      c.objectLabel, 
                      style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black), 
                      textAlign: TextAlign.center, 
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}