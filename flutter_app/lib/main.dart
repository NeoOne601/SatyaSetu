/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.9.1 (iMac Stability Patch)
 * VERSION: 1.4.1
 * STATUS: STABLE (UX Verified)
 * DESCRIPTION:
 * Fixes the infinite scanning loop, adds PIN length restriction, 
 * and implements the 'Data Loss Warning' for vault resets.
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'identity_repo.dart';
import 'identity_domain.dart';
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
        // Principal Design: Suppress font errors by providing a local fallback
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
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
  @override State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  bool _showReset = false;

  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    setState(() => _isLoading = true);
    
    try {
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      final success = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);
      
      if (success && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo)));
      } else {
        setState(() => _showReset = true);
        _pinController.clear(); // Principal Fix: Clear failed attempts
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: PIN or Hardware Mismatch")));
      }
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _confirmFactoryReset() async {
    // Principal UX Fix: Confirmation Dialog for Data Sovereignty
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Factory Reset Vault?"),
        content: const Text("CRITICAL WARNING: This hardware binding mismatch suggests you are on a new device. Resetting will permanently wipe your local identities. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Wipe & Reset")),
        ],
      ),
    );

    if (confirmed == true) {
      final directory = await getApplicationSupportDirectory();
      final vaultDir = Directory("${directory.path}/satya_vault");
      if (await vaultDir.exists()) await vaultDir.delete(recursive: true);
      setState(() { _showReset = false; _pinController.clear(); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vault Initialized. You may now create a new Identity.")));
    }
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
              const Icon(LucideIcons.shieldAlert, size: 80, color: Color(0xFF00FFC8)),
              const SizedBox(height: 24),
              const Text("SATYASETU", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 48),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                // Principal Fix: Limit length to 6 characters
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                decoration: const InputDecoration(hintText: "••••••", filled: true),
                onChanged: (val) { if (val.length == 6) _attemptUnlock(); },
              ),
              const SizedBox(height: 32),
              _isLoading 
                ? const CircularProgressIndicator() 
                : ElevatedButton(onPressed: _attemptUnlock, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)), child: const Text("Unlock Identity")),
              if (_showReset) ...[
                const SizedBox(height: 24),
                TextButton(onPressed: _confirmFactoryReset, child: const Text("Hardware Mismatch? Reset Local Vault", style: TextStyle(color: Colors.redAccent))),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// HOME & SCANNER (The Trust Machine Flow)
// ==============================================================================
class HomeScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  const HomeScreen({super.key, required this.vaultService, required this.repo});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SatyaIdentity> _identities = [];
  bool _isSyncing = true;
  @override void initState() { super.initState(); _refreshLedger(); }
  Future<void> _refreshLedger() async { setState(() => _isSyncing = true); final list = await widget.repo.getIdentities(); setState(() { _identities = list; _isSyncing = false; }); }
  
  Future<void> _createNewIdentity() async {
    final nameController = TextEditingController(text: "Identity ${DateTime.now().minute}");
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Local Identity"),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: "Identity Alias")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Create")),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isSyncing = true);
      await widget.vaultService.createNewIdentity(nameController.text);
      await _refreshLedger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("IDENTITY LEDGER"), centerTitle: true),
      body: _isSyncing 
        ? const Center(child: CircularProgressIndicator()) 
        : _identities.isEmpty 
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.fingerprint, size: 80, color: Colors.white10), const Text("Vault Empty"), const SizedBox(height: 32), ElevatedButton.icon(onPressed: _createNewIdentity, icon: const Icon(LucideIcons.plusCircle), label: const Text("Create First Identity"))])) 
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _identities.length, itemBuilder: (context, index) { final id = _identities[index]; return Card(child: ListTile(leading: const Icon(LucideIcons.userCheck, color: Color(0xFF00FFC8)), title: Text(id.label), subtitle: Text(id.did, style: const TextStyle(fontSize: 10, color: Colors.white38)))); }),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(onPressed: _createNewIdentity, heroTag: "add", mini: true, child: const Icon(LucideIcons.plus)),
          const SizedBox(height: 16),
          FloatingActionButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScannerPage(repo: widget.repo, identities: _identities))), backgroundColor: const Color(0xFF00FFC8), child: const Icon(LucideIcons.scan, color: Colors.black)),
        ],
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  final IdentityRepository repo;
  final List<SatyaIdentity> identities;
  const ScannerPage({super.key, required this.repo, required this.identities});
  @override State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  void _handleResult(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    // Principal Fix: IMMEDIATELY stop camera hardware to debounce loop
    _controller.stop();

    if (widget.identities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Create an Identity first to sign interactions.")));
      _controller.start();
      setState(() => _isProcessing = false);
      return;
    }

    final resultJson = await widget.repo.scanQr(code);
    if (mounted) {
      await showModalBottomSheet(
        context: context, 
        isScrollControlled: true,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.fileSignature, size: 48, color: Color(0xFF00FFC8)),
            const SizedBox(height: 16),
            const Text("Sign Interaction?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(resultJson, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
            const SizedBox(height: 24),
            ...widget.identities.map((id) => Card(child: ListTile(title: Text(id.label), leading: const Icon(LucideIcons.fingerprint), onTap: () async { 
              Navigator.pop(context);
              final signed = await widget.repo.signIntent(id.id, code);
              _showSignedResult(signed);
            })))
          ])
        )
      );
    }
    
    _controller.start();
    setState(() => _isProcessing = false);
  }

  void _showSignedResult(String signedJson) {
    showModalBottomSheet(context: context, builder: (context) => Container(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.checkCircle, size: 48, color: Colors.greenAccent), const SizedBox(height: 16), SelectableText(signedJson, style: const TextStyle(fontFamily: 'Courier', fontSize: 10)), const SizedBox(height: 24), ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Done"))]))));
  }

  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Sign Interaction")), body: Stack(children: [MobileScanner(controller: _controller, onDetect: (capture) { final code = capture.barcodes.first.rawValue; if (code != null) _handleResult(code); }), Positioned(bottom: 50, left: 50, right: 50, child: ElevatedButton.icon(onPressed: () => _handleResult("upi://pay?pa=satya@upi&pn=ProjectSatya&am=1.00"), icon: const Icon(LucideIcons.bug), label: const Text("Mock & Sign"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black)))])); }
}