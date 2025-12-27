/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 2.0.0
 * PHASE: Phase 7.6 (Vampire Reality)
 * GOAL: Real QR Scanning and Live Vision Overlays.
 * FIX: Resolved Dropdown reference exception and removed mocked UPI data.
 */

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    setState(() => _isLoading = true);
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
        setState(() => _isLoading = false);
      }
    } catch (_) { setState(() => _isLoading = false); }
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
                controller: _pinController, obscureText: true, textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                decoration: const InputDecoration(hintText: "••••••"),
                keyboardType: TextInputType.number,
                onChanged: (v) { if (v.length == 6) _attemptUnlock(); }
              ),
            ),
            const SizedBox(height: 32),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity")),
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
  int _currentTab = 0;
  List<SatyaIdentity> _identities = [];
  List<DetectionCandidate> _candidates = [];
  SatyaIdentity? _selectedIdentity;
  DetectionCandidate? _visionTarget;
  bool _isSigningPersona = false;
  bool _isSyncing = true;
  String _lastStatus = "Ready";

  @override void initState() {
    super.initState();
    _refresh();
    widget.visionService.candidatesStream.listen((c) {
      if (mounted && !_isSigningPersona && _currentTab == 0) setState(() => _candidates = c);
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
      // FIXED: Dropdown reference safety - find matching ID to prevent E0034/Dropdown exception
      if (_identities.isNotEmpty) {
        if (_selectedIdentity == null) {
          _selectedIdentity = _identities.first;
        } else {
          _selectedIdentity = _identities.firstWhere(
            (i) => i.id == _selectedIdentity!.id, 
            orElse: () => _identities.first
          );
        }
      }
      _isSyncing = false; 
    });
  }

  /// REAL SCANNER: Launches a dedicated QR detection overlay.
  void _openRealScanner() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text("VAMPIRE READ")),
        body: MobileScanner(
          onDetect: (capture) async {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? code = barcodes.first.rawValue;
              if (code != null && code.contains("upi://")) {
                Navigator.pop(context);
                _processUpi(code);
              }
            }
          },
        ),
      ),
    ));
  }

  Future<void> _processUpi(String rawUpi) async {
    setState(() => _lastStatus = "Decoding...");
    try {
      final jsonStr = await widget.repo.scanQr(rawUpi);
      final data = jsonDecode(jsonStr);
      if (mounted) _showInteractionSheet(data, rawUpi);
    } catch (e) {
      setState(() => _lastStatus = "Read Error");
    }
  }

  void _showInteractionSheet(Map data, String rawUpi) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.zap, color: Color(0xFF00FFC8), size: 48),
          const SizedBox(height: 16),
          Text("Pay ${data['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text("${data['amount']} ${data['currency']}", style: const TextStyle(fontSize: 32, color: Color(0xFF00FFC8))),
          const Divider(height: 32, color: Colors.white10),
          Text("Signer: ${_selectedIdentity?.label}"),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              setState(() => _lastStatus = "Broadcasting...");
              final signedJson = await widget.repo.signIntent(_selectedIdentity!.id, rawUpi);
              final ok = await widget.repo.publishToNostr(signedJson);
              setState(() => _lastStatus = ok ? "Nostr Success" : "Relay Refused");
            }, 
            child: const Text("SIGN & BROADCAST")
          )
        ]),
      )
    );
  }

  void _startVisionAdoption(DetectionCandidate candidate) {
    setState(() { _visionTarget = candidate; _isSigningPersona = true; _candidates = []; });
    widget.visionService.triggerGestureSearch();
  }

  Future<void> _finalizeNewPersona() async {
    await widget.vaultService.createNewIdentity(_visionTarget!.label);
    setState(() { _isSigningPersona = false; _visionTarget = null; });
    await _refresh();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTab == 0 ? "SATYA LENS" : _currentTab == 1 ? "HISTORY" : "SETUP"),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(_lastStatus, style: const TextStyle(fontSize: 10, color: Color(0xFF00FFC8))),
          ))
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.aperture), label: "Scanner"),
          BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(LucideIcons.settings), label: "Setup"),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 1: return _buildHistoryTab();
      case 2: return _buildSetupTab();
      default: return _buildScannerTab();
    }
  }

  Widget _buildScannerTab() {
    return Stack(children: [
      Positioned.fill(child: Opacity(opacity: 0.4, child: Platform.isMacOS 
        ? CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.macController = c)
        : const Center(child: Text("Camera Restricted")))),
      
      // LIVE VISION OVERLAY: Show what the camera is seeing
      if (_candidates.isNotEmpty && !_isSigningPersona)
        _buildVisionTargetingOverlay(),

      Column(children: [
        _buildIdentitySwitcher(),
        if (_isSigningPersona) _buildGesturePrompt(),
        if (!_isSigningPersona && _candidates.isNotEmpty) _buildCandidateShelf(),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: FloatingActionButton.extended(
            onPressed: _openRealScanner,
            icon: const Icon(LucideIcons.qrCode),
            label: const Text("VAMPIRE READ"),
            backgroundColor: const Color(0xFF00FFC8),
            foregroundColor: Colors.black,
          ),
        ),
      ])
    ]);
  }

  Widget _buildVisionTargetingOverlay() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 200, height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00FFC8), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(LucideIcons.scan, color: Color(0xFF00FFC8), size: 40),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
          child: Text("IDENTIFIED: ${_candidates.first.label}", style: const TextStyle(color: Color(0xFF00FFC8), fontSize: 12, fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }

  Widget _buildIdentitySwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.black87,
      child: Row(children: [
        const Icon(LucideIcons.user, size: 16, color: Color(0xFF00FFC8)),
        const SizedBox(width: 12),
        const Text("Active: ", style: TextStyle(fontSize: 12, color: Colors.white54)),
        if (_identities.isNotEmpty)
          DropdownButton<SatyaIdentity>(
            value: _selectedIdentity,
            underline: const SizedBox(),
            items: _identities.map((id) => DropdownMenuItem(value: id, child: Text(id.label))).toList(),
            onChanged: (v) => setState(() => _selectedIdentity = v),
          )
      ]),
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
        const Text("Perform 'Thumbs Up' Gesture to Sign", style: TextStyle(color: Colors.black54, fontSize: 11)),
      ]),
    );
  }

  Widget _buildHistoryTab() => const Center(child: Text("Interaction Ledger (Nostr Kind 29001)"));
  Widget _buildSetupTab() => Center(child: ElevatedButton(onPressed: _refresh, child: const Text("Sync HD DIDs")));
}