/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 1.8.0
 * PHASE: Phase 7.3 (Dual-Platform Camera Support)
 * DESCRIPTION: 
 * The main UI portal for SatyaSetu identity management.
 * PURPOSE:
 * Bridges the live vision stream to the identity ledger. Morphs 
 * contextually when visual anchors (Books, Utensils, Cars) are recognized.
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera/camera.dart' as mobile_camera;
import 'package:camera_macos/camera_macos.dart' as macos_camera;
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

/// SECURE ENTRY: Authenticates PIN and initializes visual sensors.
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

  /// Handshake between user PIN and hardware-bound secure vault.
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
        // Trigger the camera eyes AFTER successful unlock
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

/// ADAPTIVE PORTAL: The main interaction ledger that reacts to visual anchors.
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
    
    // Wire the late initialization callback for macOS camera preview
    widget.visionService.onInitialized = () {
      if (mounted) setState(() {});
    };
    
    // ADAPTIVE LISTENER: Rebuilds UI when the 'Brain' sees an anchor.
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

  /// PERSONA ADOPTION: Generates a contextual DID from the root.
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
          // LIVE FEED LAYER: Platform-specific camera preview
          _buildCameraPreview(),

          // ADAPTIVE INTERFACE LAYER
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
                        color: Colors.black54,
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
      floatingActionButton: _buildDevMockPanel(),
    );
  }

  /// Builds platform-specific camera preview widget
  Widget _buildCameraPreview() {
    if (!widget.visionService.isInitialized) {
      return const SizedBox.shrink();
    }

    if (Platform.isMacOS) {
      // macOS: Use CameraMacOSView widget
      return Positioned.fill(
        child: Opacity(
          opacity: 0.2,
          child: macos_camera.CameraMacOSView(
            fit: BoxFit.cover,
            cameraMode: macos_camera.CameraMacOSMode.photo,
            enableAudio: false,
            onCameraInizialized: (controller) {
              widget.visionService.onMacOSCameraInitialized(controller);
            },
          ),
        ),
      );
    } else {
      // Mobile: Use standard CameraPreview
      final camera = widget.visionService.mobileCamera;
      if (camera != null && camera.value.isInitialized) {
        return Positioned.fill(
          child: Opacity(
            opacity: 0.2,
            child: AspectRatio(
              aspectRatio: camera.value.aspectRatio,
              child: mobile_camera.CameraPreview(camera),
            ),
          ),
        );
      }
    }
    
    return const SizedBox.shrink();
  }

  /// UI COMPONENT: The Contextual Persona card (The "Morph").
  Widget _buildAdaptiveCard() {
    String title = "Anchor Found";
    IconData icon = LucideIcons.eye;
    
    switch (_currentIntent) {
      case RecognizedIntent.rideHailing: title = "Transit Persona"; icon = LucideIcons.car; break;
      case RecognizedIntent.householdAsset: title = "Asset Manager"; icon = LucideIcons.utensils; break;
      case RecognizedIntent.education: title = "Academic Persona"; icon = LucideIcons.bookOpen; break;
      case RecognizedIntent.laborRepair: title = "Technician Persona"; icon = LucideIcons.wrench; break;
      default: break;
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF00FFC8).withOpacity(0.9), 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12)]
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.black, child: Icon(icon, color: const Color(0xFF00FFC8), size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
              const Text("Visual anchor recognized. Adopt persona?", style: TextStyle(color: Colors.black54, fontSize: 11)),
            ],
          )),
          ElevatedButton(
            onPressed: () => _adoptPersona(title), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text("Adopt")
          ),
          IconButton(icon: const Icon(LucideIcons.x, color: Colors.black), onPressed: () => setState(() => _currentIntent = RecognizedIntent.none))
        ],
      ),
    );
  }

  /// DEV TOOL: Manual triggers to test UI morphing on restricted hardware.
  Widget _buildDevMockPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(heroTag: "d1", onPressed: () => widget.visionService.mockDetection(RecognizedIntent.education), backgroundColor: Colors.purple, child: const Icon(LucideIcons.bookOpen)),
        const SizedBox(height: 8),
        FloatingActionButton.small(heroTag: "d2", onPressed: () => widget.visionService.mockDetection(RecognizedIntent.householdAsset), backgroundColor: Colors.blue, child: const Icon(LucideIcons.utensils)),
        const SizedBox(height: 8),
        FloatingActionButton(heroTag: "d3", onPressed: _refresh, backgroundColor: const Color(0xFF00FFC8), child: const Icon(LucideIcons.refreshCw, color: Colors.black)),
      ],
    );
  }
}