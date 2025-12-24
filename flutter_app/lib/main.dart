/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 1.7.1
 * PHASE: Phase 7.1 (The Adaptive Interface)
 * DESCRIPTION: 
 * Main entry point of the SatyaSetu application.
 * PURPOSE:
 * Integrates the VisionService into the HomeScreen to provide a 
 * "Zero-Click" identity experience based on visual anchors.
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera/camera.dart';
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
  
  runApp(SatyaApp(
    vaultService: vaultService, 
    repo: repo, 
    visionService: visionService
  ));
}

class SatyaApp extends StatelessWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  
  const SatyaApp({
    super.key, 
    required this.vaultService, 
    required this.repo, 
    required this.visionService
  });
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SatyaSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FFC8), 
          brightness: Brightness.dark
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Verdana')
      ),
      home: UnlockScreen(
        vaultService: vaultService, 
        repo: repo, 
        visionService: visionService
      ),
    );
  }
}

/// SECURE ENTRY: Validates identity using PIN and hardware fingerprints.
class UnlockScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  
  const UnlockScreen({
    super.key, 
    required this.vaultService, 
    required this.repo, 
    required this.visionService
  });
  
  @override State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _showReset = false;

  @override
  void initState() { 
    super.initState(); 
    _pinController.clear(); 
    _focusNode.requestFocus(); 
  }

  /// Attempts to unlock the cryptographic vault.
  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    setState(() { _isLoading = true; _showReset = false; });
    try {
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      
      final success = await widget.vaultService.unlock(
        _pinController.text, 
        hwId, 
        directory.path
      );
      
      if (success && mounted) {
        // Trigger the camera hardware ONLY after valid vault entry
        await widget.visionService.initialize();
        
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HomeScreen(
            vaultService: widget.vaultService, 
            repo: widget.repo, 
            visionService: widget.visionService
          )
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
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
              const SizedBox(height: 24),
              const Text("SATYASETU", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 48),
              TextField(
                controller: _pinController, 
                focusNode: _focusNode, 
                obscureText: true, 
                enabled: !_isLoading, 
                keyboardType: TextInputType.number, 
                textAlign: TextAlign.center, 
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], 
                style: const TextStyle(fontSize: 24, letterSpacing: 16, color: Color(0xFF00FFC8)), 
                decoration: const InputDecoration(hintText: "••••••", filled: true), 
                onChanged: (v) { if (v.length == 6) _attemptUnlock(); }
              ),
              const SizedBox(height: 32),
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _attemptUnlock, child: const Text("Unlock Identity")),
              if (_showReset) 
                TextButton(
                  onPressed: () async {
                    final dir = await getApplicationSupportDirectory();
                    await widget.repo.resetVault(dir.path);
                    setState(() => _showReset = false);
                  }, 
                  child: const Text("Hardware Mismatch? Reset Local Vault", style: TextStyle(color: Colors.redAccent))
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ADAPTIVE PORTAL: Morphs between Identity Ledger and Live Vision stream.
class HomeScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  
  const HomeScreen({
    super.key, 
    required this.vaultService, 
    required this.repo, 
    required this.visionService
  });
  
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SatyaIdentity> _identities = [];
  RecognizedIntent _currentIntent = RecognizedIntent.none;
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    
    // ADAPTIVE LISTENER: Listens for visual anchors from the camera stream.
    widget.visionService.intentStream.listen((intent) {
      if (mounted) {
        setState(() => _currentIntent = intent);
        HapticFeedback.mediumImpact();
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _isSyncing = true);
    final list = await widget.repo.getIdentities();
    setState(() { _identities = list; _isSyncing = false; });
  }

  /// Creates a new DID based on the detected visual persona.
  Future<void> _adoptPersona(String type) async {
    await widget.vaultService.createNewIdentity(type);
    setState(() => _currentIntent = RecognizedIntent.none); 
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SATYA LEDGER"), 
        centerTitle: true,
        actions: [IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _refresh)]
      ),
      body: Stack(
        children: [
          // LIVE VISION LAYER: Background preview for object detection
          if (widget.visionService.controller != null && widget.visionService.controller!.value.isInitialized)
            Positioned.fill(
              child: Opacity(
                opacity: 0.25, 
                child: CameraPreview(widget.visionService.controller!),
              ),
            ),

          // ADAPTIVE IDENTITY LAYER
          Column(
            children: [
              if (_currentIntent != RecognizedIntent.none)
                _buildAdaptiveCard(),
                
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
                          title: Text(_identities[i].label),
                          subtitle: Text(_identities[i].did, style: const TextStyle(fontSize: 10, color: Colors.white30))
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _buildMockPanel(),
    );
  }

  /// UI COMPONENT: Dynamic card that appears when an object is recognized.
  Widget _buildAdaptiveCard() {
    String title = "Anchor Detected";
    IconData icon = LucideIcons.eye;
    
    switch (_currentIntent) {
      case RecognizedIntent.rideHailing:
        title = "Transit Persona"; icon = LucideIcons.car; break;
      case RecognizedIntent.householdAsset:
        title = "Household Manager"; icon = LucideIcons.utensils; break;
      case RecognizedIntent.education:
        title = "Academic Persona"; icon = LucideIcons.bookOpen; break;
      case RecognizedIntent.laborRepair:
        title = "Technician Persona"; icon = LucideIcons.wrench; break;
      default: break;
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00FFC8).withOpacity(0.9), 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
              const Text("Morph UI to this context?", style: TextStyle(color: Colors.black54, fontSize: 11)),
            ],
          )),
          ElevatedButton(
            onPressed: () => _adoptPersona(title), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: const Color(0xFF00FFC8)),
            child: const Text("Adopt")
          ),
          IconButton(icon: const Icon(LucideIcons.x, color: Colors.black), onPressed: () => setState(() => _currentIntent = RecognizedIntent.none))
        ],
      ),
    );
  }

  /// DEV TOOL: Triggers detections for testing on emulators.
  Widget _buildMockPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(heroTag: "h1", onPressed: () => widget.visionService.mockDetection(RecognizedIntent.rideHailing), backgroundColor: Colors.orange, child: const Icon(LucideIcons.car)),
        const SizedBox(height: 8),
        FloatingActionButton.small(heroTag: "h2", onPressed: () => widget.visionService.mockDetection(RecognizedIntent.householdAsset), backgroundColor: Colors.blue, child: const Icon(LucideIcons.utensils)),
        const SizedBox(height: 8),
        FloatingActionButton(heroTag: "h3", onPressed: _refresh, backgroundColor: const Color(0xFF00FFC8), child: const Icon(LucideIcons.refreshCw, color: Colors.black)),
      ],
    );
  }
}