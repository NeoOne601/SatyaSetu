import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Ensure this is in pubspec.yaml
import 'identity_repo.dart';
import 'identity_domain.dart';

void main() => runApp(const SatyaApp());

class SatyaApp extends StatelessWidget {
  const SatyaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final IdentityRepository repository = IdentityRepository();
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String status = "Satya Core Ready";
  String lastScanResult = "";
  bool isScanning = false; // Toggle for camera

  void _generateIdentity() async {
    setState(() => status = "Generating Identity...");
    final id = await widget.repository.createIdentity();
    setState(() => status = "ID: ${id.did.substring(0, 15)}...");
  }

  void _onScan(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        // Stop scanning to prevent multiple triggers
        setState(() => isScanning = false);

        final code = barcode.rawValue!;
        print("Scanned Raw Code: $code");

        // Send to Rust Brain for parsing
        final result = await widget.repository.scanQr(code);

        setState(() {
          status = "QR Parsed Successfully";
          lastScanResult = result;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
          title: const Text("SatyaSetu"),
          backgroundColor: const Color(0xFF1F2937)),
      body: Column(
        children: [
          // 1. Status Area
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black26,
            width: double.infinity,
            child: Column(
              children: [
                const Icon(Icons.shield, size: 50, color: Colors.blueAccent),
                const SizedBox(height: 10),
                Text(status, style: const TextStyle(color: Colors.white70)),
                if (lastScanResult.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text("Decoded Intent:",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                  Text(lastScanResult,
                      style: const TextStyle(
                          fontSize: 10, fontFamily: "monospace")),
                ]
              ],
            ),
          ),

          // 2. Camera / Action Area
          Expanded(
            child: isScanning
                ? Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2)),
                    child: MobileScanner(onDetect: _onScan),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text("Scan UPI QR"),
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(20),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white),
                          onPressed: () => setState(() => isScanning = true),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _generateIdentity,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent),
                          child: const Text("Generate New ID",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
