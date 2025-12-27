/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 2.2.0
 * PHASE: Phase 7.8 (The Functional Lens)
 * GOAL: Unified QR interaction, HistoryHub, and Live Vision Overlays.
 * FIX: Resolved Dropdown reference mismatch and restored Nostr broadcast path.
 */

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'identity_domain.dart';
import 'identity_repo.dart';
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
      // FIXED: Use ID comparison for Dropdown safety to prevent crash on refresh
      if (_identities.isNotEmpty) {
        if (_selectedIdentity == null) {
          _selectedIdentity = _identities.first;
        } else {
          try {
            _selectedIdentity = _identities.firstWhere((i) => i.id == _selectedIdentity!.id);
          } catch (_) {
            _selectedIdentity = _identities.first;
          }
        }
      }
      _isSyncing = false; 
    });
  }

  /// VAMPIRE READ: Opens the scanner and processes QR data.
  void _openRealScanner() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text("VAMPIRE READ")),
        body: Stack(children: [
          MobileScanner(
            onDetect: (capture) {
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
          // Simulation Button for iMac Testing
          if (Platform.isMacOS)
            Center(child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processUpi("upi://pay?pa=satya@bank&pn=Merchant&am=250&cu=INR");
              }, 
              child: const Text("Simulate QR Found")
            ))
        ]),
      ),
    ));
  }

  Future<void> _processUpi(String rawUpi) async {
    setState(() => _lastStatus = "Decoding...");
    try {
      final jsonStr = await widget.repo.scanQr(rawUpi);
      final data = jsonDecode(jsonStr);
      if (mounted) _showInteractionModal(data, rawUpi);
    } catch (e) {
      setState(() => _lastStatus = "Read Error");
    }
  }

  void _showInteractionModal(Map data, String rawUpi) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.zap, color: Color(0xFF00FFC8), size: 54),
          const SizedBox(height: 16),
          Text("${data['amount']} ${data['currency']}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00FFC8))),
          Text("Pay to: ${data['name']}", style: const TextStyle(color: Colors.white70)),
          const Divider(height: 48, color: Colors.white10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Signing Persona:"),
            Text(_selectedIdentity?.label ?? "None", style: const TextStyle(color: Color(0xFF00FFC8), fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(LucideIcons.send),
              onPressed: () async {
                Navigator.pop(c);
                setState(() => _lastStatus = "Signing...");
                final signedJson = await widget.repo.signIntent(_selectedIdentity!.id, rawUpi);
                setState(() => _lastStatus = "Broadcasting...");
                final ok = await widget.repo.publishToNostr(signedJson);
                setState(() => _lastStatus = ok ? "Nostr Active" : "Relay Failure");
              }, 
              label: const Text("SIGN & PUBLISH"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
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
    // SEMANTIC MAPPING: Groups the object under the Persona category
    final derivedLabel = "${_visionTarget!.personaType} (${_visionTarget!.objectLabel})";
    await widget.vaultService.createNewIdentity(derivedLabel);
    setState(() { _isSigningPersona = false; _visionTarget = null; });
    await _refresh();
    HapticFeedback.heavyImpact();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTab == 0 ? "SATYA LENS" : _currentTab == 1 ? "HISTORY" : "SETUP"),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 16.0), child: Text(_lastStatus, style: const TextStyle(fontSize: 10, color: Color(0xFF00FFC8))))),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        selectedItemColor: const Color(0xFF00FFC8),
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
        : const Center(child: Text("Camera Feed Unavailable")))),
      
      // LIVE VISION OVERLAY: Show raw labels directly on feed
      if (_candidates.isNotEmpty && !_isSigningPersona) _buildLiveReticle(),

      Column(children: [
        _buildIdentitySwitcher(),
        if (_isSigningPersona) _buildGesturePrompt(),
        if (!_isSigningPersona && _candidates.isNotEmpty) _buildObjectShelf(),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: FloatingActionButton.extended(
            onPressed: _openRealScanner, icon: const Icon(LucideIcons.qrCode),
            label: const Text("VAMPIRE READ"),
            backgroundColor: const Color(0xFF00FFC8), foregroundColor: Colors.black,
          ),
        ),
      ])
    ]);
  }

  Widget _buildLiveReticle() {
    final primary = _candidates.first;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 220, height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00FFC8).withOpacity(0.4), width: 1),
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Icon(LucideIcons.focus, color: Color(0xFF00FFC8), size: 24),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
          child: Text("OBJECT: ${primary.objectLabel}", style: const TextStyle(color: Color(0xFF00FFC8), fontWeight: FontWeight.bold, fontSize: 13)),
        )
      ]),
    );
  }

  Widget _buildIdentitySwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.black87,
      child: Row(children: [
        const Icon(LucideIcons.userCheck, size: 16, color: Color(0xFF00FFC8)),
        const SizedBox(width: 12),
        const Text("Signer: ", style: TextStyle(fontSize: 11, color: Colors.white54)),
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

  Widget _buildObjectShelf() {
    return Container(
      height: 90, margin: const EdgeInsets.all(16), padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: _candidates.length,
        itemBuilder: (c, i) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ActionChip(
            backgroundColor: const Color(0xFF00FFC8).withOpacity(0.05),
            avatar: const Icon(LucideIcons.plusCircle, size: 14, color: Color(0xFF00FFC8)),
            label: Text(_candidates[i].objectLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () => _startVisionAdoption(_candidates[i]),
          ),
        )
      ),
    );
  }

  Widget _buildGesturePrompt() {
    return Container(
      width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: const Color(0xFF00FFC8), borderRadius: BorderRadius.circular(32)),
      child: Column(children: [
        const Icon(LucideIcons.thumbsUp, size: 60, color: Colors.black),
        const SizedBox(height: 16),
        Text("ADOPTING: ${_visionTarget?.objectLabel}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        Text("Group: ${_visionTarget?.personaType}", style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 16),
        const Text("Perform 'Thumbs Up' Gesture to Sign", style: TextStyle(color: Colors.black, fontSize: 11, letterSpacing: 1)),
      ]),
    );
  }

  Widget _buildHistoryTab() {
    return Column(children: [
      const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text("Interaction Ledger", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _historyItem("UPI Merchant Intent", "Nostr Kind 29001", "Success"),
          _historyItem("Peer Discovery Proof", "Nostr Kind 29001", "Success"),
        ],
      ))
    ]);
  }

  Widget _historyItem(String title, String type, String status) {
    return Card(color: Colors.white10, child: ListTile(
      leading: const Icon(LucideIcons.fileSignature, color: Color(0xFF00FFC8)),
      title: Text(title), subtitle: Text(type), trailing: Text(status, style: const TextStyle(fontSize: 10, color: Colors.green)),
    ));
  }

  Widget _buildSetupTab() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text("VAULT STATUS", style: TextStyle(color: Color(0xFF00FFC8), letterSpacing: 2, fontSize: 12)),
      const ListTile(title: Text("HD Seed State"), subtitle: Text("Deterministic root derived and encrypted.")),
      const Divider(color: Colors.white10),
      const Text("NETWORK HUB", style: TextStyle(color: Color(0xFF00FFC8), letterSpacing: 2, fontSize: 12)),
      const ListTile(title: Text("Relay: Damus"), subtitle: Text("wss://relay.damus.io - ONLINE")),
      const SizedBox(height: 32),
      ElevatedButton(onPressed: _refresh, child: const Text("Sync Persona Ledger")),
    ]);
  }
}