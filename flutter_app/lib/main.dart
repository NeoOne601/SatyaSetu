/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 35.0.0
 * PHASE: Phase 49.2 (Robust Ontological UI)
 * AUTHOR: SatyaSetu Internal Neural Team
 * FIX: 
 * 1. Build Restoration: Works with updated Intent Engine.
 * 2. RenderFlex Guard: Added BoxConstraints to tiles to prevent crash on tiny AI boxes.
 * 3. Aspect Precision: Optimized for 768px retinal scan input.
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
import 'identity_repo.dart';
import 'models/intent_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = IdentityRepository();
  final vaultService = VaultService(repo);
  final visionService = VisionService();
  debugPrint("flutter: SATYA_DEBUG: [SYSTEM] Robust Bootstrap.");
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied")));
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
    final state = candidate.situation;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(state.title.toUpperCase(), style: TextStyle(letterSpacing: 2, fontSize: 10, color: state.themeColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(candidate.objectLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const Divider(height: 40, color: Colors.white10),
              ...state.actions.map((action) => ListTile(
                onTap: () { Navigator.pop(c); action.onExecute(context); },
                leading: Icon(action.icon, color: state.themeColor),
                title: Text(action.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(action.description, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.white24),
              )),
            ],
          ),
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
          
          ..._candidates.map((c) => _buildMorphicTile(c, constraints.maxWidth, constraints.maxHeight)),
          
          const Positioned(top: 60, left: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("SATYA SETU", style: TextStyle(letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00FFC8))),
            Text("ONTOLOGICAL SIGHT ACTIVE", style: TextStyle(fontSize: 8, color: Colors.white38)),
          ])),
        ]);
      }),
    );
  }

  Widget _buildMorphicTile(DetectionCandidate c, double screenW, double screenH) {
    final Color color = c.isLiving ? const Color(0xFFFF4545) : c.situation.themeColor;
    
    // GUARD: Ensure the tile has a minimum visible size even if AI detects a tiny sub-pixel region
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
            color: color.withOpacity(0.05),
            border: Border.all(color: color.withOpacity(0.8), width: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.zap, size: 7, color: Colors.black.withOpacity(0.6)),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        c.objectLabel, 
                        style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black), 
                        textAlign: TextAlign.center, 
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
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