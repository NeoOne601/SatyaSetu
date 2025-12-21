/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 5.0 (The Signed Interaction)
 * VERSION: 1.2.2
 * STATUS: STABLE (Functional Signing UI)
 * DESCRIPTION:
 * Main entry point. Manages Secure Unlock and Identity Signing flows.
 * CHANGE LOG:
 * - Phase 4.0: Identity Ledger persistence verified.
 * - Phase 5.0: Integration of Sign-Interaction bottom sheets.
 */

import 'dart:io';
import 'package:flutter/material.dart';
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
    if (_pinController.text.length < 4) return;
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      final success = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);
      if (success && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vault Access Denied")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            Text("SatyaSetu Vault", style: GoogleFonts.orbitron(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 16, color: Color(0xFF00FFC8)),
              decoration: InputDecoration(hintText: "••••••", filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 32),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _attemptUnlock, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: const Color(0xFF00FFC8), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Unlock Identity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// HOME: IDENTITY LEDGER
// ==============================================================================
class HomeScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  const HomeScreen({super.key, required this.vaultService, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SatyaIdentity> _identities = [];
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _refreshLedger();
  }

  Future<void> _refreshLedger() async {
    setState(() => _isSyncing = true);
    final list = await widget.repo.getIdentities();
    setState(() { _identities = list; _isSyncing = false; });
  }

  Future<void> _showCreateIdentityDialog() async {
    final labelController = TextEditingController(text: "Satya Primary");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Generate Identity"),
        content: TextField(controller: labelController, decoration: const InputDecoration(labelText: "Alias")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async { Navigator.pop(context); setState(() => _isSyncing = true); await widget.vaultService.createNewIdentity(labelController.text); await _refreshLedger(); }, child: const Text("Generate"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("SATYASETU", style: GoogleFonts.orbitron(fontSize: 20)), centerTitle: true, actions: [IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _refreshLedger)]),
      body: _isSyncing ? const Center(child: CircularProgressIndicator()) : _identities.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.fingerprint, size: 80, color: Colors.white10), const SizedBox(height: 16), const Text("Vault Empty", style: TextStyle(color: Colors.white24, fontSize: 18)), const SizedBox(height: 32), ElevatedButton(onPressed: _showCreateIdentityDialog, child: const Text("Create First Identity"))])) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _identities.length, itemBuilder: (context, index) { final id = _identities[index]; return Card(color: Colors.white.withOpacity(0.05), margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: const Icon(LucideIcons.userCheck, color: Color(0xFF00FFC8)), title: Text(id.label, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(id.did, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white38)), trailing: const Icon(LucideIcons.chevronRight, size: 16))); }),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScannerPage(repo: widget.repo, identities: _identities))), backgroundColor: const Color(0xFF00FFC8), child: const Icon(LucideIcons.scan, color: Colors.black)),
      bottomNavigationBar: BottomAppBar(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [TextButton.icon(onPressed: _showCreateIdentityDialog, icon: const Icon(LucideIcons.plus), label: const Text("Add")), TextButton.icon(onPressed: () { widget.vaultService.lock(); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => UnlockScreen(vaultService: widget.vaultService, repo: widget.repo))); }, icon: const Icon(LucideIcons.lock), label: const Text("Lock"))])),
    );
  }
}

// ==============================================================================
// SCANNER: SIGN-INTERACTION FLOW
// ==============================================================================
class ScannerPage extends StatefulWidget {
  final IdentityRepository repo;
  final List<SatyaIdentity> identities;
  const ScannerPage({super.key, required this.repo, required this.identities});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _isProcessing = false;
  void _handleResult(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    if (widget.identities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No identities found to sign interaction")));
      setState(() => _isProcessing = false);
      return;
    }
    final resultJson = await widget.repo.scanQr(code);
    if (mounted) {
      _showSignConfirmation(code, resultJson);
    }
  }

  void _showSignConfirmation(String rawCode, String parsedJson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.fileSignature, size: 48, color: Color(0xFF00FFC8)),
            const SizedBox(height: 16),
            const Text("Sign Interaction?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(parsedJson, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 24),
            const Text("Select Identity to Sign With:"),
            const SizedBox(height: 12),
            ...widget.identities.map((id) => Card(
              color: Colors.white10,
              child: ListTile(
                title: Text(id.label),
                leading: const Icon(LucideIcons.fingerprint, color: Color(0xFF00FFC8)),
                onTap: () async {
                  Navigator.pop(context);
                  final signedJson = await widget.repo.signIntent(id.id, rawCode);
                  _showSignedResult(signedJson);
                },
              ),
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    setState(() => _isProcessing = false);
  }

  void _showSignedResult(String signedJson) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.checkCircle, size: 48, color: Colors.greenAccent),
              const SizedBox(height: 16),
              const Text("Signed Proof Generated", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)), child: SelectableText(signedJson, style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.greenAccent))),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("Done")),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Transaction")),
      body: Stack(
        children: [
          MobileScanner(onDetect: (capture) { final code = capture.barcodes.first.rawValue; if (code != null) _handleResult(code); }),
          Positioned(
            bottom: 50, left: 50, right: 50,
            child: ElevatedButton.icon(
              onPressed: () => _handleResult("upi://pay?pa=satya@upi&pn=ProjectSatya&am=1.00"),
              icon: const Icon(LucideIcons.bug),
              label: const Text("Mock & Sign"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black),
            ),
          )
        ],
      ),
    );
  }
}