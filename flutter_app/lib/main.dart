/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 1.8.0
 * PHASE: Phase 7.4 (The Unified Hub)
 * GOAL: Restore QR Scanning and Nostr Broadcasting within the HD-Identity architecture.
 * NEW: Added Identity Switcher, UPI Interaction Modal, and Nostr Status feedback.
 */

import 'dart:io';
import 'dart:convert';
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
  bool _isLoading = false;
  bool _showReset = false;

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
        _pinController.clear();
        setState(() { _isLoading = false; _showReset = true; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _showReset = true; });
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
            const SizedBox(height: 48),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: TextField(
                controller: _pinController, 
                obscureText: true, 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                decoration: const InputDecoration(hintText: "••••••"),
                keyboardType: TextInputType.number,
                onChanged: (v) { if (v.length == 6) _attemptUnlock(); }
              ),
            ),
            const SizedBox(height: 32),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity Vault")),
            if (_showReset)
              TextButton(
                onPressed: () async {
                  final dir = await getApplicationSupportDirectory();
                  await widget.repo.resetVault(dir.path);
                  setState(() { _showReset = false; });
                }, 
                child: const Text("Reset Local Data", style: TextStyle(color: Colors.redAccent))
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
  SatyaIdentity? _selectedIdentity;
  DetectionCandidate? _visionTarget;
  bool _isSigningPersona = false;
  bool _isSyncing = true;

  @override void initState() {
    super.initState();
    _refresh();
    widget.visionService.candidatesStream.listen((c) {
      if (mounted && !_isSigningPersona) setState(() => _candidates = c);
    });
    widget.visionService.gestureStream.listen((g) {
      if (g == RecognizedGesture.thumbsUp && _visionTarget != null) _finalizeNewPersona();
    });
  }

  Future<void> _refresh() async {
    setState(() => _isSyncing = true);
    final list = await widget.repo.getIdentities();
    setState(() { 
      _identities = list; 
      if (_identities.isNotEmpty && _selectedIdentity == null) {
        _selectedIdentity = _identities.first;
      }
      _isSyncing = false; 
    });
  }

  /// RESTORED: Trigger the QR interaction flow (The Vampire Strategy)
  Future<void> _startQrInteraction() async {
    // Mocking the scan result for iMac testing - in reality this would come from a QR controller
    const mockUpi = "upi://pay?pa=satya@bank&pn=Merchant&am=100&cu=INR";
    final jsonStr = await widget.repo.scanQr(mockUpi);
    final data = jsonDecode(jsonStr);

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (c) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.qrCode, color: Color(0xFF00FFC8)),
              const SizedBox(height: 16),
              Text("Payment Intent: ${data['name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("${data['amount']} ${data['currency']}", style: const TextStyle(fontSize: 24, color: Color(0xFF00FFC8))),
              const Divider(height: 32),
              Text("Signing with: ${_selectedIdentity?.label ?? 'Default'}"),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(c);
                  final signedJson = await widget.repo.signIntent(_selectedIdentity!.id, mockUpi);
                  final ok = await widget.repo.publishToNostr(signedJson);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? "Broadcast Successful (Nostr)" : "Broadcast Failed")));
                }, 
                child: const Text("Sign & Publish to Nostr")
              )
            ],
          ),
        )
      );
    }
  }

  void _startVisionAdoption(DetectionCandidate candidate) {
    setState(() { _visionTarget = candidate; _isSigningPersona = true; _candidates = []; });
    widget.visionService.triggerGestureSearch();
  }

  Future<void> _finalizeNewPersona() async {
    await widget.vaultService.createNewIdentity(_visionTarget!.label);
    setState(() { _isSigningPersona = false; _visionTarget = null; });
    await _refresh();
    HapticFeedback.vibrate();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SATYA HUB", style: TextStyle(letterSpacing: 2)),
        actions: [
          IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _refresh)
        ],
      ),
      body: Stack(children: [
        // Camera Layer
        Positioned.fill(child: Opacity(opacity: 0.3, child: Platform.isMacOS 
          ? CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.macController = c)
          : (widget.visionService.mobileController?.value.isInitialized ?? false) ? CameraPreview(widget.visionService.mobileController!) : const Center(child: Text("Initializing...")))),
        
        Column(children: [
          _buildIdentitySwitcher(),
          if (_isSigningPersona) _buildGesturePrompt(),
          if (!_isSigningPersona && _candidates.isNotEmpty) _buildCandidateShelf(),
          
          Expanded(child: _buildPersonaList()),
          
          _buildActionHub(),
        ])
      ]),
    );
  }

  Widget _buildIdentitySwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black87,
      child: Row(children: [
        const Icon(LucideIcons.user, size: 16, color: Color(0xFF00FFC8)),
        const SizedBox(width: 12),
        const Text("Active Persona: ", style: TextStyle(fontSize: 12, color: Colors.white54)),
        DropdownButton<SatyaIdentity>(
          value: _selectedIdentity,
          underline: const SizedBox(),
          items: _identities.map((id) => DropdownMenuItem(value: id, child: Text(id.label))).toList(),
          onChanged: (v) => setState(() => _selectedIdentity = v),
        )
      ]),
    );
  }

  Widget _buildPersonaList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _identities.length,
      itemBuilder: (c, i) => Card(
        color: _identities[i].id == _selectedIdentity?.id ? Colors.white10 : Colors.black45,
        child: ListTile(
          leading: Icon(LucideIcons.fingerprint, color: _identities[i].id == _selectedIdentity?.id ? const Color(0xFF00FFC8) : Colors.white24),
          title: Text(_identities[i].label),
          subtitle: Text(_identities[i].did, style: const TextStyle(fontSize: 10, color: Colors.white30)),
        ),
      ),
    );
  }

  Widget _buildCandidateShelf() {
    return Container(
      height: 80, margin: const EdgeInsets.all(16), padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00FFC8))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: _candidates.length,
        itemBuilder: (c, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(avatar: const Icon(LucideIcons.plus, size: 14), label: Text(_candidates[i].label), onPressed: () => _startVisionAdoption(_candidates[i])))
      ),
    );
  }

  Widget _buildGesturePrompt() {
    return Container(
      width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF00FFC8), borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        const Icon(LucideIcons.thumbsUp, size: 48, color: Colors.black),
        const SizedBox(height: 12),
        Text("ADOPTING: ${_visionTarget?.label}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        const Text("Perform 'Thumbs Up' to sign and derive this persona", style: TextStyle(color: Colors.black54, fontSize: 11)),
      ]),
    );
  }

  Widget _buildActionHub() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _hubButton(LucideIcons.qrCode, "Scan QR", _startQrInteraction),
        _hubButton(LucideIcons.history, "History", () {}),
        _hubButton(LucideIcons.settings, "Setup", () {}),
      ]),
    );
  }

  Widget _hubButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: const Color(0xFF00FFC8))),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54))
      ]),
    );
  }
}