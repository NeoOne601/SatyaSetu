/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 1.7.8
 * PHASE: Phase 7.3 (Gesture Signatures)
 * DESCRIPTION: 
 * Main entry point of SatyaSetu with Gesture-Based Signatures.
 * PURPOSE:
 * Implements a two-step handshake: 1. Select Object -> 2. Perform Gesture.
 * This ensures the user is in full control of identity registration.
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'identity_repo.dart';
import 'identity_domain.dart';
import 'services/vault_service.dart';
import 'services/hardware_id_service.dart';
import 'services/vision_service.dart';

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
  @override Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00FFC8), brightness: Brightness.dark)),
      home: UnlockScreen(vaultService: vaultService, repo: repo, visionService: visionService),
    );
  }
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
    setState(() => _isLoading = true);
    final directory = await getApplicationSupportDirectory();
    final hwId = await HardwareIdService.getDeviceId();
    final success = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);
    if (success && mounted) {
      await widget.visionService.initialize();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo, visionService: widget.visionService)));
    } else {
      _pinController.clear();
      setState(() => _isLoading = false);
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
      const SizedBox(height: 48),
      Container(constraints: const BoxConstraints(maxWidth: 300), child: TextField(controller: _pinController, obscureText: true, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 16), decoration: const InputDecoration(hintText: "••••••"), keyboardType: TextInputType.number, onChanged: (v) { if (v.length == 6) _attemptUnlock(); })),
      const SizedBox(height: 32),
      _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Vault"))
    ])));
  }
}

class HomeScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  const HomeScreen({super.key, required this.vaultService, required this.repo, required this.visionService});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SatyaIdentity> _identities = [];
  List<DetectionCandidate> _activeCandidates = [];
  DetectionCandidate? _selectedCandidate;
  bool _isSigning = false;
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.visionService.onInitialized = () { if (mounted) setState(() {}); };
    widget.visionService.candidatesStream.listen((c) { if (mounted && !_isSigning) setState(() => _activeCandidates = c); });
    
    // GESTURE LISTENER: Signs the identity when Thumbs Up is detected
    widget.visionService.gestureStream.listen((gesture) {
      if (gesture == RecognizedGesture.thumbsUp && _selectedCandidate != null) {
        _finalizeRegistration();
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _isSyncing = true);
    final list = await widget.repo.getIdentities();
    setState(() { _identities = list; _isSyncing = false; });
  }

  void _startSigning(DetectionCandidate candidate) {
    setState(() {
      _selectedCandidate = candidate;
      _isSigning = true;
      _activeCandidates = [];
    });
    widget.visionService.triggerGestureSearch();
  }

  Future<void> _finalizeRegistration() async {
    if (_selectedCandidate == null) return;
    await widget.vaultService.createNewIdentity(_selectedCandidate!.label);
    setState(() { _isSigning = false; _selectedCandidate = null; });
    await _refresh();
    HapticFeedback.heavyImpact();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SATYA SCANNER"), centerTitle: true),
      body: Stack(children: [
        Positioned.fill(child: Opacity(opacity: 0.3, child: Platform.isMacOS 
          ? CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.macController = c)
          : (widget.visionService.mobileController?.value.isInitialized ?? false) ? CameraPreview(widget.visionService.mobileController!) : const Center(child: Text("Loading...")))),
        
        Column(children: [
          if (_isSigning) _buildGesturePrompt(),
          if (!_isSigning && _activeCandidates.isNotEmpty) _buildSelectionShelf(),
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _identities.length, itemBuilder: (c, i) => Card(color: Colors.black54, child: ListTile(leading: const Icon(LucideIcons.userCheck, color: Color(0xFF00FFC8)), title: Text(_identities[i].label), subtitle: Text(_identities[i].did, style: const TextStyle(fontSize: 10, color: Colors.white30)))))),
        ])
      ]),
    );
  }

  Widget _buildSelectionShelf() {
    return Container(height: 100, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00FFC8))), child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _activeCandidates.length, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(_activeCandidates[i].label), onPressed: () => _startSigning(_activeCandidates[i])))));
  }

  Widget _buildGesturePrompt() {
    return Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF00FFC8), borderRadius: BorderRadius.circular(24)), child: Column(children: [
      const Icon(LucideIcons.thumbsUp, size: 48, color: Colors.black),
      const SizedBox(height: 12),
      Text("SIGNING: ${_selectedCandidate?.label}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      const Text("Perform 'Thumbs Up' to finalize registration", style: TextStyle(color: Colors.black54, fontSize: 12)),
      TextButton(onPressed: () => setState(() => _isSigning = false), child: const Text("Cancel", style: TextStyle(color: Colors.red)))
    ]));
  }
}