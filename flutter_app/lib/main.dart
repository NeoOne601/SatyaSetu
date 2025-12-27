/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 1.7.10
 * PHASE: Phase 7.3 (Active Handshake)
 * FIX: Restored 'Reset Local Vault' button to resolve stuck unlock screens caused by legacy data.
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
  bool _showReset = false; // Restored state variable

  @override
  void initState() { 
    super.initState(); 
    _pinController.clear(); 
    _focusNode.requestFocus(); 
  }

  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    setState(() { _isLoading = true; _showReset = false; });
    try {
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      final success = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);
      
      if (success && mounted) {
        // Only initialize vision after success to save resources
        await widget.visionService.initialize();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo, visionService: widget.visionService)
        ));
      } else {
        // Failed unlock: Clear PIN and Show Reset Option
        _pinController.clear();
        _focusNode.requestFocus();
        setState(() {
          _isLoading = false;
          _showReset = true; // Allow user to escape bad state
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: Invalid PIN or Corrupt Vault")));
      }
    } catch (e) {
      print("UNLOCK ERROR: $e");
      setState(() {
        _isLoading = false;
        _showReset = true;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override Widget build(BuildContext context) {
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
                controller: _pinController, 
                focusNode: _focusNode, 
                obscureText: true, 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 24, letterSpacing: 16, color: Color(0xFF00FFC8)), 
                decoration: const InputDecoration(hintText: "••••••", filled: true), 
                keyboardType: TextInputType.number, 
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                onChanged: (v) { if (v.length == 6) _attemptUnlock(); }
              ),
            ),
            const SizedBox(height: 32),
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity")),
            
            // RESTORED: The escape hatch for corrupted vaults
            if (_showReset)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: TextButton(
                  onPressed: () async {
                    final dir = await getApplicationSupportDirectory();
                    // Call the Native Reset from Identity Repo
                    await widget.repo.resetVault(dir.path);
                    setState(() { _showReset = false; });
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vault Purged. Please enter PIN to create new vault.")));
                  },
                  child: const Text("Vault Error? Reset Local Data", style: TextStyle(color: Colors.redAccent)),
                ),
              )
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
  List<DetectionCandidate> _candidates = [];
  DetectionCandidate? _selected;
  bool _isSigning = false;
  bool _isSyncing = true;

  @override void initState() {
    super.initState();
    _refresh();
    widget.visionService.onInitialized = () { if (mounted) setState(() {}); };
    widget.visionService.candidatesStream.listen((c) { if (mounted && !_isSigning) setState(() => _candidates = c); });
    widget.visionService.gestureStream.listen((g) { if (g == RecognizedGesture.thumbsUp && _selected != null) _finalize(); });
  }

  Future<void> _refresh() async {
    setState(() => _isSyncing = true);
    final list = await widget.repo.getIdentities();
    setState(() { _identities = list; _isSyncing = false; });
  }

  void _startSigning(DetectionCandidate candidate) {
    setState(() { _selected = candidate; _isSigning = true; _candidates = []; });
    widget.visionService.triggerGestureSearch();
  }

  Future<void> _finalize() async {
    await widget.vaultService.createNewIdentity(_selected!.label);
    setState(() { _isSigning = false; _selected = null; });
    await _refresh();
    HapticFeedback.vibrate();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SATYA SCANNER"), centerTitle: true),
      body: Stack(children: [
        Positioned.fill(child: Opacity(opacity: 0.25, child: Platform.isMacOS 
          ? CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.macController = c)
          : (widget.visionService.mobileController?.value.isInitialized ?? false) ? CameraPreview(widget.visionService.mobileController!) : const Center(child: Text("Initializing...")))),
        Column(children: [
          if (_isSigning) _buildGesturePrompt(),
          if (!_isSigning && _candidates.isNotEmpty) _buildCandidateShelf(),
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _identities.length, itemBuilder: (c, i) => Card(color: Colors.black54, child: ListTile(leading: const Icon(LucideIcons.userCheck, color: Color(0xFF00FFC8)), title: Text(_identities[i].label), subtitle: Text(_identities[i].did, style: const TextStyle(fontSize: 10, color: Colors.white30)))))),
        ])
      ]),
    );
  }

  Widget _buildCandidateShelf() {
    return Container(height: 90, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00FFC8))), child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _candidates.length, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(avatar: const Icon(LucideIcons.plus, size: 14), label: Text(_candidates[i].label), onPressed: () => _startSigning(_candidates[i])))));
  }

  Widget _buildGesturePrompt() {
    return Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF00FFC8), borderRadius: BorderRadius.circular(24)), child: Column(children: [
      const Icon(LucideIcons.thumbsUp, size: 48, color: Colors.black),
      const SizedBox(height: 12),
      Text("SIGNING: ${_selected?.label}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      const Text("Perform 'Thumbs Up' to finalize persona registration", style: TextStyle(color: Colors.black54, fontSize: 12)),
      TextButton(onPressed: () => setState(() => _isSigning = false), child: const Text("Cancel", style: TextStyle(color: Colors.red)))
    ]));
  }
}