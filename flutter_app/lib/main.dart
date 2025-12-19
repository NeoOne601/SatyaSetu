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
  // Ensure the framework is ready for FFI and Path calls
  WidgetsFlutterBinding.ensureInitialized();
  
  // Principal Design: Initialize the repository singleton via Factory
  final repo = IdentityRepository();
  final vaultService = VaultService(repo);
  
  runApp(SatyaApp(vaultService: vaultService, repo: repo));
}

class SatyaApp extends StatelessWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  const SatyaApp({super.key, required this.vaultService, required this.repo});

  // Helper to handle font loading failure gracefully
  TextStyle getSafeStyle(TextStyle? googleStyle, TextStyle fallback) {
    try {
      return googleStyle ?? fallback;
    } catch (e) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SatyaSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FFC8),
          brightness: Brightness.dark,
        ),
      ),
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
    if (_pinController.text.length < 4) {
      _showError("PIN must be at least 4 digits");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      
      final success = await widget.vaultService.unlock(
        _pinController.text, 
        hwId, 
        directory.path
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(repo: widget.repo)),
        );
      } else {
        _showError("Access Denied: PIN or Hardware Mismatch");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
            const SizedBox(height: 24),
            Text("SatyaSetu Vault", 
              style: GoogleFonts.orbitron(fontSize: 28, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            const Text("Silicon-Locked Identity", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 48),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 16, color: Color(0xFF00FFC8)),
              decoration: InputDecoration(
                hintText: "••••••",
                hintStyle: const TextStyle(color: Colors.white10),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: _attemptUnlock,
                  icon: const Icon(LucideIcons.unlock),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    backgroundColor: const Color(0xFF00FFC8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  label: const Text("Unlock Identity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
          ],
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
      appBar: AppBar(
        title: Text("SatyaSetu", style: GoogleFonts.orbitron(fontSize: 20)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.lock, size: 100, color: Colors.greenAccent),
            const SizedBox(height: 24),
            const Text("Vault Unlocked", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Identity active in RAM. Proceed to Interaction.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ScannerPage(repo: repo)),
                );
              },
              icon: const Icon(LucideIcons.scan),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 60),
                backgroundColor: const Color(0xFF00FFC8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
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

    print("SATYA_DEBUG: Calling Rust Parser for code: $code");
    final resultJson = await widget.repo.scanQr(code);
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.fileSearch, size: 48, color: Color(0xFF00FFC8)),
              const SizedBox(height: 16),
              const Text("Parsed Intent (Rust Core)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: SelectableText(resultJson, 
                  style: const TextStyle(fontFamily: 'Courier', color: Colors.greenAccent)
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we are on a simulator (x86_64 or similar)
    // On simulators, MobileScanner often shows nothing. 
    final isSimulator = !Platform.isAndroid && !Platform.isIOS; // Simplistic check or use device_info

    return Scaffold(
      appBar: AppBar(title: const Text("Vampire Scanner")),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
            ),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) _handleResult(code);
              }
            },
          ),
          // Principal Design: Add a manual entry button for Simulator Testing
          Positioned(
            bottom: 50,
            left: 50,
            right: 50,
            child: Column(
              children: [
                const Text("Simulator Detected? Use Mock Scan", style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _handleResult("upi://pay?pa=satya@upi&pn=ProjectSatya&am=10.00&cu=INR"),//Testing with dummy qr scan object in iPhone simulator
                  icon: const Icon(LucideIcons.bug),
                  label: const Text("Inject Mock UPI QR"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}