/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 1.7.6
 * PHASE: Phase 7.2 (The Adaptive Interface)
 * DESCRIPTION: 
 * Main entry point of SatyaSetu with Active Intent Recognition.
 * PURPOSE:
 * Displays real-time 'Detection Chips' on top of the camera feed.
 * Enables users to explicitly select which physical object to register.
 * FIXED: 'onCameraInizialized' (plugin specific spelling) and 'cameraMode' sync.
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
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SatyaSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00FFC8), brightness: Brightness.dark),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Verdana')
      ),
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
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _showReset = false;

  @override
  void initState() { super.initState(); _pinController.clear(); _focusNode.requestFocus(); }

  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    setState(() { _isLoading = true; _showReset = false; });
    try {
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      final success = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);
      if (success && mounted) {
        await widget.visionService.initialize();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo, visionService: widget.visionService)
        ));
      } else {
        setState(() => _showReset = true);
        _pinController.clear();
        _focusNode.requestFocus();
      }
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
            const SizedBox(height: 24),
            const Text("SATYASETU", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 48),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: TextField(
                controller: _pinController, focusNode: _focusNode, obscureText: true, enabled: !_isLoading, 
                keyboardType: TextInputType.number, textAlign: TextAlign.center, 
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], 
                style: const TextStyle(fontSize: 24, letterSpacing: 16, color: Color(0xFF00FFC8)), 
                decoration: const InputDecoration(hintText: "••••••", filled: true), 
                onChanged: (v) { if (v.length == 6) _attemptUnlock(); }
              ),
            ),
            const SizedBox(height: 32),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity")),
            if (_showReset) TextButton(onPressed: () async {
                final dir = await getApplicationSupportDirectory();
                await widget.repo.resetVault(dir.path);
                setState(() => _showReset = false);
              }, child: const Text("Reset Local Vault", style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      ),
    );
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
  RecognizedIntent _selectedIntent = RecognizedIntent.none;
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    
    widget.visionService.onInitialized = () { if (mounted) setState(() {}); };
    
    // ACTIVE SCANNER: Listen for multiple detection candidates
    widget.visionService.candidatesStream.listen((candidates) {
      if (mounted) setState(() => _activeCandidates = candidates);
    });
  }

  Future<void> _refresh() async {
    setState(() => _isSyncing = true);
    final list = await widget.repo.getIdentities();
    setState(() { _identities = list; _isSyncing = false; });
  }

  Future<void> _confirmPersona(DetectionCandidate candidate) async {
    await widget.vaultService.createNewIdentity(candidate.label);
    setState(() {
      _selectedIntent = RecognizedIntent.none;
      _activeCandidates.clear();
    });
    await _refresh();
    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SATYA SCANNER"), centerTitle: true,
        actions: [IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _refresh)] 
      ),
      body: Stack(
        children: [
          // LIVE LENS: The constant eye of the application
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Platform.isMacOS 
                ? CameraMacOSView(
                    cameraMode: CameraMacOSMode.photo, 
                    onCameraInizialized: (controller) {
                      widget.visionService.macController = controller;
                    },
                  )
                : (widget.visionService.mobileController?.value.isInitialized ?? false)
                  ? CameraPreview(widget.visionService.mobileController!)
                  : const Center(child: Text("Initializing Vision Brain...")),
            ),
          ),

          // THE SMART OVERLAY: Displays detected candidates for selection
          Column(
            children: [
              if (_activeCandidates.isNotEmpty) _buildScannerOverlay(),
              
              Expanded(
                child: _isSyncing 
                  ? const Center(child: CircularProgressIndicator()) 
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _identities.length,
                      itemBuilder: (c, i) => Card(
                        color: Colors.black45,
                        child: ListTile(
                          leading: const Icon(LucideIcons.userCheck, color: Color(0xFF00FFC8)),
                          title: Text(_identities[i].label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(_identities[i].did, style: const TextStyle(fontSize: 10, color: Colors.white30))
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// UI COMPONENT: The horizontal scanner that shows what the camera 'sees'.
  Widget _buildScannerOverlay() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00FFC8), width: 1)
      ),
      child: Column(
        children: [
          const Text("DETECTED OBJECTS (TAP TO REGISTER)", style: TextStyle(fontSize: 9, letterSpacing: 2, color: Color(0xFF00FFC8))),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _activeCandidates.length,
              itemBuilder: (c, i) => _buildCandidateChip(_activeCandidates[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateChip(DetectionCandidate candidate) {
    IconData icon = LucideIcons.box;
    if (candidate.intent == RecognizedIntent.rideHailing) icon = LucideIcons.car;
    if (candidate.intent == RecognizedIntent.education) icon = LucideIcons.bookOpen;
    if (candidate.intent == RecognizedIntent.householdAsset) icon = LucideIcons.utensils;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: Colors.black),
        backgroundColor: const Color(0xFF00FFC8),
        label: Text("${candidate.label} (${(candidate.confidence * 100).toInt()}%)", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
        onPressed: () => _confirmPersona(candidate),
      ),
    );
  }
}