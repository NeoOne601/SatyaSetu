/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 29.0.0
 * PHASE: Phase 42.0 (Atomic Semantic UI)
 * FIX: 
 * 1. Semantic Color Logic: Intelligently separates Living from Objects.
 * 2. Visual Persistence: 0.7px borders for high-density object detection.
 * 3. Fluidity: Faster reticle animations (150ms).
 */

import 'dart:io';
import 'dart:convert';
import 'dart:async';
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
  debugPrint("flutter: SATYA_DEBUG: [SYSTEM] Bootstrap.");
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
      home: UnlockScreen(vaultService: vaultService, repo: repo, visionService: visionService)
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

  @override Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
      const SizedBox(height: 48),
      Container(constraints: const BoxConstraints(maxWidth: 300), child: TextField(controller: _pinController, obscureText: true, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: "••••••"), keyboardType: TextInputType.number, onChanged: (v) { if (v.length == 6) _attemptUnlock(); })),
      const SizedBox(height: 32),
      _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity Vault"))
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
  int _currentTab = 0;
  List<SatyaIdentity> _identities = [];
  List<DetectionCandidate> _candidates = [];
  List<dynamic> _history = [];
  String? _selectedIdentityId; 
  bool _isSyncing = true;
  String _aiStatus = "Sensing Reality...";

  @override void initState() {
    super.initState();
    _refresh();
    widget.visionService.initialize();

    widget.visionService.candidatesStream.listen((c) {
      if (mounted && _currentTab == 0) {
        setState(() => _candidates = c);
      }
    });

    widget.visionService.statusStream.listen((s) {
      if (mounted) setState(() => _aiStatus = s);
    });
  }

  Future<void> _refresh() async {
    setState(() => _isSyncing = true);
    final list = await widget.repo.getIdentities();
    final hStrings = await widget.repo.fetchInteractionHistory();
    setState(() { 
      _identities = list; 
      _history = hStrings.map((s) => jsonDecode(s)).toList();
      if (_identities.isNotEmpty && _selectedIdentityId == null) _selectedIdentityId = _identities.first.id;
      _isSyncing = false; 
    });
  }

  void _openRealScanner() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => Scaffold(appBar: AppBar(title: const Text("VAMPIRE READ")), body: Stack(children: [
      MobileScanner(onDetect: (capture) {
        final code = capture.barcodes.first.rawValue;
        if (code != null && code.contains("upi://")) { 
          Navigator.pop(context); 
          _processUpi(code); 
        }
      }),
      if (Platform.isMacOS) Center(child: ElevatedButton(onPressed: () { 
        Navigator.pop(context); 
        _processUpi("upi://pay?pa=satya@bank&pn=SatyaAppleTier&am=100&cu=INR"); 
      }, child: const Text("Simulation: QR Simulated")))
    ]))));
  }

  Future<void> _processUpi(String raw) async {
    final json = await widget.repo.scanQr(raw);
    final data = jsonDecode(json);
    if (mounted) _showInteractionModal(data, raw);
  }

  void _showInteractionModal(Map data, String raw) {
    showModalBottomSheet(context: context, backgroundColor: Colors.black, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))), builder: (c) => Container(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(LucideIcons.zap, color: Color(0xFF00FFC8), size: 54),
      const SizedBox(height: 12),
      Text("${data['amount']} ${data['currency']}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00FFC8))),
      const Divider(height: 48, color: Colors.white10),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(LucideIcons.send), onPressed: () async {
        Navigator.pop(c);
        if (_selectedIdentityId == null) return;
        final signed = await widget.repo.signIntent(_selectedIdentityId!, raw);
        await widget.repo.publishToNostr(signed);
        _refresh();
      }, label: const Text("SIGN & BROADCAST")))
    ])));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentTab == 0 ? "IDENTITY LENS" : _currentTab == 1 ? "PROOF LEDGER" : "SETUP"), actions: [IconButton(icon: const Icon(LucideIcons.refreshCw, size: 18), onPressed: _refresh)]),
      body: _buildBody(),
      floatingActionButton: _currentTab == 0 ? FloatingActionButton.extended(
        onPressed: _openRealScanner, 
        icon: const Icon(LucideIcons.qrCode), 
        label: const Text("VAMPIRE READ"), 
        backgroundColor: const Color(0xFF00FFC8), 
        foregroundColor: Colors.black
      ) : null,
      bottomNavigationBar: BottomNavigationBar(currentIndex: _currentTab, onTap: (i) => setState(() => _currentTab = i), selectedItemColor: const Color(0xFF00FFC8), items: const [
        BottomNavigationBarItem(icon: Icon(LucideIcons.aperture), label: "Lens"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: "Ledger"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.settings), label: "Setup"),
      ]),
    );
  }

  Widget _buildBody() {
    if (_currentTab == 1) return _buildHistoryTab();
    if (_currentTab == 2) return _buildSetupTab();
    return _buildScannerTab();
  }

  Widget _buildScannerTab() => LayoutBuilder(builder: (context, constraints) {
    return Stack(children: [
      Positioned.fill(child: Opacity(opacity: 0.4, child: Platform.isMacOS 
        ? CameraMacOSView(
            cameraMode: CameraMacOSMode.photo, 
            onCameraInizialized: (c) => widget.visionService.attachCamera(c)
          )
        : const Center(child: Text("Silicon Feed Bound")))),
      
      ..._candidates.map((c) => _buildAnimatedReticle(c, constraints.maxWidth, constraints.maxHeight)),
      
      Column(children: [
        _buildIdentitySwitcher(),
        const Spacer(),
      ])
    ]);
  });

  Widget _buildAnimatedReticle(DetectionCandidate c, double screenW, double screenH) {
    // ATOMIC SEMANTIC COLOR LOGIC
    // Living beings = Neon Red, Objects = Satya Green.
    final Color reticleColor = c.isLiving ? const Color(0xFFFF4545) : const Color(0xFF00FFC8);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      left: c.relativeLocation.left * screenW,
      top: c.relativeLocation.top * screenH,
      width: c.relativeLocation.width * screenW,
      height: c.relativeLocation.height * screenH,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: reticleColor.withOpacity(0.8), width: 0.7), 
          borderRadius: BorderRadius.circular(4)
        ),
        child: Stack(children: [
          Positioned(
            top: 0.5, left: 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5), 
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(2)), 
              child: Text(
                c.objectLabel, 
                style: TextStyle(fontSize: 5, color: reticleColor, fontWeight: FontWeight.bold, letterSpacing: 0.1)
              )
            )
          )
        ]),
      ),
    );
  }

  Widget _buildIdentitySwitcher() => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.black87, child: Row(children: [
    const Icon(LucideIcons.zap, size: 16, color: Color(0xFF00FFC8)),
    const SizedBox(width: 12),
    Text(_aiStatus, style: const TextStyle(fontSize: 12, color: Colors.white54)),
    const Spacer(),
    if (_identities.isNotEmpty) DropdownButton<String>(value: _selectedIdentityId, underline: const SizedBox(), items: _identities.map((id) => DropdownMenuItem(value: id.id, child: Text(id.label))).toList(), onChanged: (v) => setState(() => _selectedIdentityId = v))
  ]));

  Widget _buildHistoryTab() {
    if (_isSyncing) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Syncing Swarm Ledger...")]));
    if (_history.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.cloudOff, size: 48, color: Colors.white24), const SizedBox(height: 16), const Text("No Proofs Found"), const SizedBox(height: 24), ElevatedButton(onPressed: _refresh, child: const Text("Force Swarm Sync"))]));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: _history.length, itemBuilder: (c, i) {
      final item = _history[i];
      final upi = item['payload']['upi_data'];
      final bool verified = item['is_verified'] ?? false;
      return Card(color: Colors.white10, child: ListTile(
        leading: Icon(LucideIcons.shieldCheck, color: verified ? const Color(0xFF00FFC8) : Colors.orange),
        title: Text("To: ${upi['name']}"),
        subtitle: Text("ID: ${item['signer_did']}", style: const TextStyle(fontSize: 8)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("${upi['amount']} ${upi['currency']}", style: const TextStyle(color: Color(0xFF00FFC8), fontWeight: FontWeight.bold)),
          if (verified) const Text("VERIFIED PROOF", style: TextStyle(fontSize: 6, color: Color(0xFF00FFC8), letterSpacing: 1)),
        ]),
      ));
    });
  }

  Widget _buildSetupTab() => ListView(padding: const EdgeInsets.all(24), children: [
    const Text("VAULT SECURITY", style: TextStyle(color: Color(0xFF00FFC8), letterSpacing: 2, fontSize: 11)),
    const ListTile(title: Text("HD Root Seed"), subtitle: Text("Bound to silicon entropy active.")),
    const Divider(color: Colors.white10),
    const Text("NETWORK PROXIMITY", style: TextStyle(color: Color(0xFF00FFC8), letterSpacing: 2, fontSize: 11)),
    const ListTile(title: Text("Swarm Relays"), subtitle: Text("Damus, Nostr.band - ACTIVE")),
    const SizedBox(height: 48),
    ElevatedButton(onPressed: () async {
      final dir = await getApplicationSupportDirectory();
      await widget.repo.resetVault(dir.path);
      Future.delayed(const Duration(seconds: 1), () => exit(0));
    }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)), child: const Text("Reset Local Data", style: TextStyle(color: Colors.redAccent)))
  ]);
}