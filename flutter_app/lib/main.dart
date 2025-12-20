// Adding Persistence and Security
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'identity_repo.dart';
import 'services/vault_service.dart';
import 'services/hardware_id_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = IdentityRepository();
  final vaultService = VaultService(repo);
  runApp(SatyaApp(vaultService: vaultService, repo: repo));
}

class SatyaApp extends StatelessWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  const SatyaApp({super.key, required this.vaultService, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SatyaSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00FFC8), brightness: Brightness.dark),
      ),
      // Principal Design: No fonts in top level theme to prevent AssetManifest crash
      home: UnlockScreen(vaultService: vaultService, repo: repo),
    );
  }
}

// ==============================================================================
// GATEKEEPER: SECURE UNLOCK SCREEN
// ==============================================================================
class UnlockScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  const UnlockScreen({super.key, required this.vaultService, required this.repo});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 4) return;
    setState(() => _isLoading = true);
    
    try {
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      final success = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);

      if (success && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(repo: widget.repo)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
              const SizedBox(height: 24),
              const Text("SatyaSetu Vault", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text("Silicon-Locked Identity", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 48),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                decoration: const InputDecoration(hintText: "••••••", filled: true, border: InputBorder.none),
              ),
              const SizedBox(height: 32),
              _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _attemptUnlock,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: const Color(0xFF00FFC8), foregroundColor: Colors.black),
                    child: const Text("Unlock Vault"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// HOME: DECRYPTED INTERFACE
// ==============================================================================
class HomeScreen extends StatelessWidget {
  final IdentityRepository repo;
  const HomeScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SatyaSetu")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.lock, size: 100, color: Colors.greenAccent),
            const SizedBox(height: 24),
            const Text("Vault Unlocked", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScannerPage(repo: repo))),
              icon: const Icon(LucideIcons.scan),
              style: ElevatedButton.styleFrom(minimumSize: const Size(250, 60)),
              label: const Text("Scan UPI QR"),
            )
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// SCANNER: VAMPIRE MODE (SIMULATOR COMPATIBLE)
// ==============================================================================
class ScannerPage extends StatefulWidget {
  final IdentityRepository repo;
  const ScannerPage({super.key, required this.repo});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _isProcessing = false;

  void _handleResult(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      print("SATYA_DEBUG: Initiating Rust Call for: $code");
      // This is the line where the bridge mismatch previously caused the crash
      final resultJson = await widget.repo.scanQr(code);
      print("SATYA_DEBUG: Rust Response Received: $resultJson");
      
      if (mounted) {
        _showBottomSheet(resultJson);
      }
    } catch (e) {
      print("SATYA_DEBUG: FFI Call Failure: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showBottomSheet(String content) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Parsed Intent (Rust Core)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(content, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vampire Scanner")),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final code = capture.barcodes.first.rawValue;
              if (code != null) _handleResult(code);
            },
          ),
          Positioned(
            bottom: 50, left: 50, right: 50,
            child: ElevatedButton.icon(
              onPressed: () => _handleResult("upi://pay?pa=satya@upi&pn=ProjectSatya&am=1.00"),
              icon: const Icon(LucideIcons.bug),
              label: const Text("Inject Mock UPI QR"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          )
        ],
      ),
    );
  }
}