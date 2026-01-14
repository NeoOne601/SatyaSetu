/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 84.3.0
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: Industrial Grade Trust Interface.
 * FIX: Implemented "Cover" scaling for CameraPreview to prevent stretching/distortion.
 */

import 'dart:convert';
import 'dart:async';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:camera/camera.dart'; 
import 'services/vault_service.dart';
import 'services/vision_service.dart';
import 'services/hardware_id_service.dart';
import 'services/intent_harvester.dart';
import 'services/intent_engine.dart';
import 'identity_repo.dart';
import 'models/intent_models.dart';

import 'screens/radar_view.dart';
import 'screens/mission_control_screen.dart';

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
  CameraController? _mobileCameraController;
  bool _isMobileCameraReady = false;
  
  @override void initState() {
    super.initState();
    widget.visionService.initialize();
    widget.visionService.candidatesStream.listen((c) { if (mounted) setState(() => _candidates = c); });
    
    if (!Platform.isMacOS) {
      _initMobileCamera();
    }
  }

  Future<void> _initMobileCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _mobileCameraController = CameraController(
        firstCamera, 
        ResolutionPreset.medium, // Using medium for faster inference/transfer
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      );
      
      await _mobileCameraController!.initialize();
      
      if (mounted) {
        setState(() => _isMobileCameraReady = true);
        widget.visionService.attachMobileCamera(_mobileCameraController!);
      }
    } catch (e) {
      debugPrint("flutter: Failed to init mobile camera: $e");
    }
  }

  @override void dispose() {
    _mobileCameraController?.dispose();
    super.dispose();
  }

  void _showIntentCard(DetectionCandidate candidate) {
    widget.visionService.isPaused = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (c) => _AffordanceModal(
        candidate: candidate,
        repo: widget.repo,
        onClose: () => Navigator.pop(c),
      ),
    ).whenComplete(() {
      widget.visionService.isPaused = false;
    });
  }

  void _openMissionControl() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MissionControlScreen()));
  }

  /// Builds the mobile camera preview with correct Aspect Ratio scaling
  Widget _buildMobileCameraPreview(BoxConstraints constraints) {
    if (!_isMobileCameraReady || _mobileCameraController == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC8)));
    }

    final camera = _mobileCameraController!.value;
    final size = constraints.biggest;
    
    // Calculate scale to "Cover" the screen
    // Camera aspect ratio is usually inverted on mobile portrait (width < height)
    double scale = size.aspectRatio * camera.aspectRatio;

    // Adjust scale if it's less than 1 to ensure coverage
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(_mobileCameraController!),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          // LAYER 1: PLATFORM AWARE CAMERA
          Positioned.fill(
            child: Opacity(
              opacity: 0.6, // Increased opacity slightly for better visibility
              child: Platform.isMacOS 
                ? CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.attachCamera(c))
                : _buildMobileCameraPreview(constraints)
            )
          ),
          
          // LAYER 2: AUGMENTED REALITY OVERLAYS
          ..._candidates.map((c) => _buildMorphicTile(c, constraints.maxWidth, constraints.maxHeight)),
          
          // LAYER 3: HUD TOP
          Positioned(
            top: 60, left: 24, right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("SATYA SETU", style: TextStyle(letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00FFC8))),
                  const Text("RECOVERY HUB ACTIVE", style: TextStyle(fontSize: 8, color: Colors.white38)),
                ]),
                IconButton(
                  onPressed: _openMissionControl,
                  icon: const Icon(LucideIcons.activity, color: Color(0xFF00FFC8), size: 28),
                  tooltip: "Mission Control",
                )
              ],
            )
          ),

          // LAYER 4: HUD BOTTOM (RADAR)
          Positioned(
            bottom: 30, right: 20, 
            child: SizedBox(width: 100, height: 100, child: RadarView(candidates: _candidates))
          ),
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

class _AffordanceModal extends StatefulWidget {
  final DetectionCandidate candidate;
  final IdentityRepository repo;
  final VoidCallback onClose;
  const _AffordanceModal({required this.candidate, required this.repo, required this.onClose});
  @override State<_AffordanceModal> createState() => _AffordanceModalState();
}

class _AffordanceModalState extends State<_AffordanceModal> {
  ActivitySession? _session;
  bool _showRating = false;
  int _selectedRating = 0;
  
  void _completeStep(String affordanceName, int stepIndex) {
    if (_session == null) return;
    setState(() => _session!.completeStep(affordanceName, stepIndex));
  }
  
  void _showRatingDialog() => setState(() => _showRating = true);
  
  Future<void> _finishAndStore() async {
    if (_session == null || _selectedRating == 0) return;
    final completedSession = IntentEngine.endSession(_selectedRating);
    if (completedSession != null) {
      await IntentHarvester.harvestSession(widget.repo, completedSession);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Stored to DID ledger • Trust +${((completedSession.userRating ?? 0) * 10 + completedSession.completedStepCount * 5).clamp(0, 100)}"),
          backgroundColor: const Color(0xFF00FFC8),
          duration: const Duration(seconds: 2),
        ));
      }
    }
    widget.onClose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: _showRating ? _buildRatingView() : _buildAffordanceView(),
      ),
    );
  }
  
  Widget _buildAffordanceView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(widget.candidate.objectLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const Divider(height: 24, color: Colors.white10),
          FutureBuilder<ApeResponse>(
            future: IntentEngine.fetchAffordances(widget.candidate.objectLabel, "general"),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator(color: Color(0xFF00FFC8));
              final plan = snapshot.data!;
              if (plan.affordances.isEmpty) return const Text("No affordances.", style: TextStyle(color: Colors.white38));
              _session ??= IntentEngine.startSession(widget.candidate.objectLabel, plan);
              return Column(children: [
                if (_session != null) LinearProgressIndicator(value: _session!.completionPercentage, valueColor: const AlwaysStoppedAnimation(Color(0xFF00FFC8))),
                ...plan.affordances.map((aff) => ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(aff.name.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    children: aff.actions.map((act) {
                      final isCompleted = _session?.isStepCompleted(aff.name, act.step) ?? false;
                      return ListTile(
                        dense: true,
                        leading: GestureDetector(onTap: () => _completeStep(aff.name, act.step), child: Icon(isCompleted ? LucideIcons.check : LucideIcons.circle, color: isCompleted ? const Color(0xFF00FFC8) : Colors.white24, size: 16)),
                        title: Text(act.instruction, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null, color: isCompleted ? Colors.white38 : Colors.white)),
                        onTap: () => _completeStep(aff.name, act.step),
                      );
                    }).toList(),
                  )),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _session != null && _session!.completedStepCount > 0 ? _showRatingDialog : null, icon: const Icon(LucideIcons.star, size: 16), label: const Text("COMPLETE"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFC8), foregroundColor: Colors.black))),
              ]);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildRatingView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.star, size: 40, color: Color(0xFF00FFC8)),
        const SizedBox(height: 16),
        const Text("RATE EXPERIENCE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(onTap: () => setState(() => _selectedRating = i + 1), child: Padding(padding: const EdgeInsets.all(8), child: Icon(LucideIcons.star, size: 36, color: i < _selectedRating ? const Color(0xFFFFD700) : Colors.white24))))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _selectedRating > 0 ? _finishAndStore : null, icon: const Icon(LucideIcons.fingerprint), label: const Text("STORE TO DID"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFC8), foregroundColor: Colors.black))),
    ]);
  }
}