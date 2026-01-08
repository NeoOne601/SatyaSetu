/**
 * FILE: flutter_app/lib/main.dart
 * VERSION: 84.0.0
 * AUTHOR: SatyaSetu Principal Engineer
 * DESCRIPTION: Industrial Grade Trust Interface.
 * FIX: Hardware Isolation Protocol: Vision loop pauses while reasoning works.
 * FIX: Restored varying box colors based on detection labels.
 */

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:camera_macos/camera_macos.dart';
import 'services/vault_service.dart';
import 'services/vision_service.dart';
import 'services/hardware_id_service.dart';
import 'services/intent_harvester.dart';
import 'services/intent_engine.dart';
import 'services/mission_control_service.dart'; 
import 'identity_repo.dart';
import 'models/intent_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SatyaApp(
    vaultService: VaultService(IdentityRepository()), 
    repo: IdentityRepository(), 
    visionService: VisionService()
  ));
}

class SatyaApp extends StatelessWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  const SatyaApp({super.key, required this.vaultService, required this.repo, required this.visionService});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, 
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00FFC8), brightness: Brightness.dark)), 
    home: UnlockScreen(vaultService: vaultService, repo: repo, visionService: visionService)
  );
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
    final hwId = await HardwareIdService.getDeviceId(); 
    final dir = await getApplicationSupportDirectory();
    final ok = await widget.vaultService.unlock(_pinController.text, hwId, dir.path);
    if (ok && mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(vaultService: widget.vaultService, repo: widget.repo, visionService: widget.visionService)));
    else setState(() => _isLoading = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(LucideIcons.shieldCheck, size: 80, color: Color(0xFF00FFC8)),
    const SizedBox(height: 32),
    SizedBox(width: 200, child: TextField(controller: _pinController, obscureText: true, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: "PIN"), keyboardType: TextInputType.number, onChanged: (v) { if (v.length == 6) _attemptUnlock(); })),
  ])));
}

class HomeScreen extends StatefulWidget {
  final VaultService vaultService;
  final IdentityRepository repo;
  final VisionService visionService;
  const HomeScreen({super.key, required this.vaultService, required this.repo, required this.visionService});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DetectionCandidate> _candidates = [];
  
  @override void initState() {
    super.initState();
    widget.visionService.initialize();
    widget.visionService.candidatesStream.listen((c) { if (mounted) setState(() => _candidates = c); });
  }

  void _showIntentCard(DetectionCandidate candidate) {
    // HARDWARE ISOLATION: Pause the eyes to give the brain the GPU
    widget.visionService.isPaused = true;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (c) => _AffordanceModal(
        candidate: candidate,
        repo: widget.repo,
        onClose: () => Navigator.pop(c),
      ),
    ).whenComplete(() {
      // RESUME VISION
      widget.visionService.isPaused = false;
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          Positioned.fill(child: Opacity(opacity: 0.5, child: CameraMacOSView(cameraMode: CameraMacOSMode.photo, onCameraInizialized: (c) => widget.visionService.attachCamera(c)))),
          ..._candidates.map((c) => _buildMorphicTile(c, constraints.maxWidth, constraints.maxHeight)),
          Positioned(top: 60, left: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("SATYA SETU", style: TextStyle(letterSpacing: 4, fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00FFC8))),
            const Text("RECOVERY HUB ACTIVE", style: TextStyle(fontSize: 8, color: Colors.white38)),
          ])),
        ]);
      }),
    );
  }

  Widget _buildMorphicTile(DetectionCandidate c, double screenW, double screenH) {
    // FIXED: Restored vibrant colors based on label hash
    final Color baseColor = IntentEngine.generateVibrantColor(c.objectLabel); 
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: (c.relativeLocation.left * screenW).clamp(0, screenW - 50),
      top: (c.relativeLocation.top * screenH).clamp(0, screenH - 50),
      width: (c.relativeLocation.width * screenW).clamp(45.0, screenW),
      height: (c.relativeLocation.height * screenH).clamp(35.0, screenH),
      child: GestureDetector(
        onTap: () => _showIntentCard(c),
        child: Container(
          decoration: BoxDecoration(color: baseColor.withOpacity(0.1), border: Border.all(color: baseColor.withOpacity(0.8), width: 1.0), borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4), decoration: BoxDecoration(color: baseColor.withOpacity(0.85), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6))), child: Center(child: Text(c.objectLabel, style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black), overflow: TextOverflow.ellipsis)))]),
        ),
      ),
    );
  }
}

/// Interactive Affordance Modal with Step Completion and Rating
class _AffordanceModal extends StatefulWidget {
  final DetectionCandidate candidate;
  final IdentityRepository repo;
  final VoidCallback onClose;
  
  const _AffordanceModal({required this.candidate, required this.repo, required this.onClose});
  
  @override State<_AffordanceModal> createState() => _AffordanceModalState();
}

class _AffordanceModalState extends State<_AffordanceModal> {
  ActivitySession? _session;
  bool _showRating = false;
  int _selectedRating = 0;
  
  void _completeStep(String affordanceName, int stepIndex) {
    if (_session == null) return;
    setState(() {
      _session!.completeStep(affordanceName, stepIndex);
    });
  }
  
  void _showRatingDialog() {
    setState(() => _showRating = true);
  }
  
  Future<void> _finishAndStore() async {
    if (_session == null || _selectedRating == 0) return;
    
    final completedSession = IntentEngine.endSession(_selectedRating);
    if (completedSession != null) {
      await IntentHarvester.harvestSession(widget.repo, completedSession);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Stored to DID ledger • Trust +${((completedSession.userRating ?? 0) * 10 + completedSession.completedStepCount * 5).clamp(0, 100)}"),
          backgroundColor: const Color(0xFF00FFC8),
          duration: const Duration(seconds: 2),
        ));
      }
    }
    widget.onClose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: _showRating ? _buildRatingView() : _buildAffordanceView(),
      ),
    );
  }
  
  Widget _buildAffordanceView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(widget.candidate.objectLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const Divider(height: 24, color: Colors.white10),
          
          const Row(children: [
            Icon(LucideIcons.listChecks, size: 14, color: Colors.blueAccent), 
            SizedBox(width: 8), 
            Text("AFFORDANCE ACTION CHAINS", style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.blueAccent))
          ]),
          const SizedBox(height: 12),

          FutureBuilder<ApeResponse>(
            future: IntentEngine.fetchAffordances(widget.candidate.objectLabel, "general"),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Column(children: [
                    CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFC8)),
                    SizedBox(height: 12),
                    Text("Loading affordances...", style: TextStyle(fontSize: 11, color: Colors.white38)),
                  ])),
                );
              }
              
              final plan = snapshot.data!;
              if (plan.affordances.isEmpty) {
                return const ListTile(title: Text("No affordances available.", style: TextStyle(fontSize: 12, color: Colors.white38)));
              }
              
              // Start session if not started
              _session ??= IntentEngine.startSession(widget.candidate.objectLabel, plan);
              
              return Column(children: [
                // Progress bar
                if (_session != null) ...[
                  LinearProgressIndicator(
                    value: _session!.completionPercentage,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00FFC8)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "${_session!.completedStepCount}/${_session!.totalSteps} steps completed",
                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ),
                ],
                
                // Affordances with checkable steps
                ...plan.affordances.map((aff) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(aff.name.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    children: aff.actions.map((act) {
                      final isCompleted = _session?.isStepCompleted(aff.name, act.step) ?? false;
                      return ListTile(
                        dense: true,
                        leading: GestureDetector(
                          onTap: () => _completeStep(aff.name, act.step),
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: isCompleted ? const Color(0xFF00FFC8) : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: isCompleted 
                              ? const Icon(LucideIcons.check, size: 14, color: Colors.black)
                              : Center(child: Text("${act.step}", style: const TextStyle(fontSize: 9))),
                          ),
                        ),
                        title: Text(
                          act.instruction, 
                          style: TextStyle(
                            fontSize: 11, 
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? Colors.white38 : Colors.white,
                          ),
                        ),
                        trailing: act.recordable ? const Icon(LucideIcons.fingerprint, size: 14, color: Color(0xFF00FFC8)) : null,
                        onTap: () => _completeStep(aff.name, act.step),
                      );
                    }).toList(),
                  ),
                )),
                
                const SizedBox(height: 16),
                
                // Complete button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _session != null && _session!.completedStepCount > 0 ? _showRatingDialog : null,
                    icon: const Icon(LucideIcons.star, size: 16),
                    label: const Text("COMPLETE & RATE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFC8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildRatingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        const Icon(LucideIcons.star, size: 40, color: Color(0xFF00FFC8)),
        const SizedBox(height: 16),
        const Text("RATE YOUR EXPERIENCE", style: TextStyle(fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(height: 8),
        Text(widget.candidate.objectLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        // Star rating
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => _selectedRating = i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                i < _selectedRating ? LucideIcons.star : LucideIcons.star,
                size: 36,
                color: i < _selectedRating ? const Color(0xFFFFD700) : Colors.white24,
              ),
            ),
          )),
        ),
        
        const SizedBox(height: 24),
        
        if (_session != null)
          Text(
            "${_session!.completedStepCount}/${_session!.totalSteps} steps • +${((_selectedRating) * 10 + _session!.completedStepCount * 5).clamp(0, 100)} trust",
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        
        const SizedBox(height: 24),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedRating > 0 ? _finishAndStore : null,
            icon: const Icon(LucideIcons.fingerprint, size: 16),
            label: const Text("STORE TO DID LEDGER"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFC8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        TextButton(
          onPressed: () => setState(() => _showRating = false),
          child: const Text("← Back to steps", style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}