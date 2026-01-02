/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 31.0.0
 * PHASE: Phase 47.3 (Morphic UI Interaction)
 * DESCRIPTION: Implements floating interactive tiles that trigger context-aware cards.
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
  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    final directory = await getApplicationSupportDirectory();
    final ok = await widget.vaultService.unlock(_pinController.text, "HW-ID-MAC", directory.path);
    if (ok && mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo, visionService: widget.visionService)));
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
    const SizedBox(height: 48),
    Container(constraints: const BoxConstraints(maxWidth: 300), child: TextField(controller: _pinController, obscureText: true, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: "••••••"), keyboardType: TextInputType.number, onChanged: (v) { if (v.length == 6) _attemptUnlock(); })),
    const SizedBox(height: 32),
    ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity Vault"))
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
    final state = candidate.situation;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(state.title.toUpperCase(), style: TextStyle(letterSpacing: 2, fontSize: 10, color: state.themeColor)),
            const SizedBox(height: 8),
            Text(candidate.objectLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Divider(height: 40, color: Colors.white10),
            ...state.actions.map((action) => ListTile(
              onTap: () {
                Navigator.pop(c);
                action.onExecute(context);
              },
              leading: Icon(action.icon, color: state.themeColor),
              title: Text(action.label),
              subtitle: Text(action.description, style: const TextStyle(fontSize: 10, color: Colors.white54)),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
            )),
          ],
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          Positioned.fill(child: Opacity(opacity: 0.5, child: CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.attachCamera(c)))),
          
          // FLOATING MORPHIC TILES
          ..._candidates.map((c) => _buildMorphicTile(c, constraints.maxWidth, constraints.maxHeight)),
          
          const Positioned(top: 60, left: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("SATYA SETU", style: TextStyle(letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00FFC8))),
            Text("INTENT OVERLAY ACTIVE", style: TextStyle(fontSize: 8, color: Colors.white38)),
          ])),
        ]);
      }),
    );
  }

  Widget _buildMorphicTile(DetectionCandidate c, double screenW, double screenH) {
    final Color color = c.isLiving ? const Color(0xFFFF4545) : c.situation.themeColor;
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: c.relativeLocation.left * screenW,
      top: c.relativeLocation.top * screenH,
      width: c.relativeLocation.width * screenW,
      height: c.relativeLocation.height * screenH,
      child: GestureDetector(
        onTap: () => _showIntentCard(c),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            border: Border.all(color: color.withOpacity(0.6), width: 1.0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10))),
                child: Text(c.objectLabel, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}