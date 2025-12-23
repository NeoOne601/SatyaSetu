/**
 * PROJECT SATYA: SECURE IDENTITY BRIDGE
 * =====================================
 * PHASE: 6.5 (The Decentralized Proof)
 * VERSION: 1.6.5
 * STATUS: STABLE (Broadcast Ready)
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
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00FFC8), brightness: Brightness.dark), textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Verdana')),
      home: UnlockScreen(vaultService: vaultService, repo: repo),
    );
  }
}

class UnlockScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  const UnlockScreen({super.key, required this.vaultService, required this.repo});
  @override State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _showReset = false;

  @override
  void initState() { super.initState(); _pinController.clear(); _focusNode.requestFocus(); }

  Future<void> _attemptUnlock() async {
    if (_pinController.text.length < 6) return;
    setState(() { _isLoading = true; _showReset = false; });
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final directory = await getApplicationSupportDirectory();
      final hwId = await HardwareIdService.getDeviceId();
      final success = await widget.vaultService.unlock(_pinController.text, hwId, directory.path);
      if (success && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo)));
      } else {
        setState(() => _showReset = true);
        _pinController.clear();
        _focusNode.requestFocus();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vault Access Denied")));
      }
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _factoryReset() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Factory Reset?"), content: const Text("Resetting will permanently wipe all identities. Continue?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Reset"))]));
    if (confirmed == true) {
      final directory = await getApplicationSupportDirectory();
      final vaultDir = Directory("${directory.path}/satya_vault");
      // PRINCIPAL FIX: Aggressively delete the entire vault directory for macOS reset stability
      if (await vaultDir.exists()) {
        await vaultDir.delete(recursive: true);
      }
      _pinController.clear();
      setState(() => _showReset = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vault Cleaned. Create new identity.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Container(constraints: const BoxConstraints(maxWidth: 400), padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
              const SizedBox(height: 24),
              const Text("SATYASETU", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 48),
              TextField(controller: _pinController, focusNode: _focusNode, obscureText: true, enabled: !_isLoading, keyboardType: TextInputType.number, textAlign: TextAlign.center, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], style: const TextStyle(fontSize: 24, letterSpacing: 16, color: Color(0xFF00FFC8)), decoration: const InputDecoration(hintText: "••••••", filled: true), onChanged: (v) { if (v.length == 6) _attemptUnlock(); }),
              const SizedBox(height: 32),
              _isLoading ? const Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Computing Silicon Keys...", style: TextStyle(fontSize: 10, color: Colors.white24))]) : ElevatedButton(onPressed: _attemptUnlock, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)), child: const Text("Unlock Identity")),
              if (_showReset) TextButton(onPressed: _factoryReset, child: const Text("Hardware Mismatch? Reset Local Vault", style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  const HomeScreen({super.key, required this.vaultService, required this.repo});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SatyaIdentity> _identities = [];
  bool _isSyncing = true;
  @override void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async { setState(() => _isSyncing = true); final list = await widget.repo.getIdentities(); setState(() { _identities = list; _isSyncing = false; }); }

  Future<void> _createNew() async {
    final name = TextEditingController(text: "Merchant ${DateTime.now().minute}");
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("New Identity"), content: TextField(controller: name), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Generate"))]));
    if (ok == true) { await widget.vaultService.createNewIdentity(name.text); await _refresh(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LEDGER"), centerTitle: true, actions: [IconButton(icon: const Icon(LucideIcons.plusCircle), onPressed: _createNew)]),
      body: _isSyncing ? const Center(child: CircularProgressIndicator()) : _identities.isEmpty ? Center(child: ElevatedButton.icon(onPressed: _createNew, icon: const Icon(LucideIcons.plus), label: const Text("Create First Identity"))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _identities.length, itemBuilder: (c, i) => Card(child: ListTile(leading: const Icon(LucideIcons.userCheck, color: Color(0xFF00FFC8)), title: Text(_identities[i].label), subtitle: Text(_identities[i].did, style: const TextStyle(fontSize: 10, color: Colors.white30))))),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScannerPage(repo: widget.repo, identities: _identities))), backgroundColor: const Color(0xFF00FFC8), child: const Icon(LucideIcons.scan, color: Colors.black)),
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
    _controller.stop();
    final result = await widget.repo.scanQr(code);
    if (mounted) {
      await showModalBottomSheet(
        context: context, 
        isScrollControlled: true,
        builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.fileSignature, size: 48, color: Color(0xFF00FFC8)),
            const SizedBox(height: 16),
            const Text("Sign Interaction?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(result, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
            const SizedBox(height: 24),
            ...widget.identities.map((id) => Card(child: ListTile(title: Text(id.label), leading: const Icon(LucideIcons.fingerprint), onTap: () async { 
              Navigator.pop(ctx);
              final signed = await widget.repo.signIntent(id.id, code);
              _showResult(signed);
            })))
          ]))
      );
    }
    _controller.start();
    setState(() => _isProcessing = false);
  }

  void _showResult(String signed) {
    bool isBroadcasting = false;
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(LucideIcons.checkCircle, size: 48, color: Colors.greenAccent),
              const SizedBox(height: 16),
              const Text("Signed Proof Generated", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)), child: SelectableText(signed, style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.greenAccent))),
              const SizedBox(height: 24),
              if (isBroadcasting) const Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text("Broadcasting to global relays...", style: TextStyle(fontSize: 10))]) 
              else ElevatedButton.icon(
                onPressed: () async {
                  setModalState(() => isBroadcasting = true);
                  final success = await widget.repo.publishToNostr(signed);
                  setModalState(() => isBroadcasting = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success ? "Broadcast Successful to Global Network" : "Broadcast Failed: Check Connection"),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ));
                    if (success) Navigator.pop(context);
                  }
                }, 
                icon: const Icon(LucideIcons.rss), 
                label: const Text("Broadcast to Global Network"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF00FFC8), foregroundColor: Colors.black),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
            ],
          ))),
      ),
    );
  }

  @override Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(title: const Text("Scanner")), 
      body: Stack(children: [
        MobileScanner(
          controller: _controller, 
          onDetect: (c) { 
            // PRINCIPAL FIX: Defensive guard for empty barcode list to prevent RangeError crash
            if (c.barcodes.isNotEmpty && c.barcodes.first.rawValue != null) {
              _handleResult(c.barcodes.first.rawValue!); 
            }
          }
        ), 
        Positioned(bottom: 50, left: 50, right: 50, child: ElevatedButton.icon(onPressed: () => _handleResult("upi://pay?pa=satya@upi&pn=ProjectSatya&am=1.00"), icon: const Icon(LucideIcons.bug), label: const Text("Mock & Sign"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black)))
      ])
    ); 
  }
}