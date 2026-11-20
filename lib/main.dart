import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_video_editor/easy_video_editor.dart';

const String appName = "Viral Clip Studio";
const String appVersion = "1.0.0";
const String watermarkText = "Made with Viral Clip Studio";
const String razorpayPaymentUrl = "https://razorpay.me/@avinashkumar7447";
const List<String> activeLicenseKeys = ["VCS-NOV26-PRO", "VCS-DEC26-PRO", "VCS-PRO-998877"];
const int planValidityDays = 30;
const String adNetworkDirectUrl = "https://www.highperformanceformat.com";

void main() {
  runApp(const ViralClipStudioApp());
}

class ViralClipStudioApp extends StatelessWidget {
  const ViralClipStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF58A6FF),
        cardColor: const Color(0xFF161B22),
      ),
      home: const HomeWorkspace(),
    );
  }
}

class HomeWorkspace extends StatefulWidget {
  const HomeWorkspace({super.key});

  @override
  State<HomeWorkspace> createState() => _HomeWorkspaceState();
}

class _HomeWorkspaceState extends State<HomeWorkspace> {
  int _selectedIndex = 0;
  bool _isPro = false;
  int _daysLeft = 0;
  String _statusText = "✨ Viral Clip Studio Mobile Ready!";
  bool _isBusy = false;

  String? _shortsVideoPath;
  String _shortsDuration = "30";
  final TextEditingController _hookController = TextEditingController();

  String? _beatVideoPath;
  String? _beatAudioPath;
  String _beatDuration = "30";

  final TextEditingController _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final bool active = prefs.getBool("pro_active") ?? false;
    final String? expStr = prefs.getString("expiry_date");
    if (active && expStr != null) {
      final expDate = DateTime.tryParse(expStr);
      if (expDate != null && DateTime.now().isBefore(expDate)) {
        setState(() {
          _isPro = true;
          _daysLeft = expDate.difference(DateTime.now()).inDays + 1;
        });
        return;
      } else {
        await prefs.setBool("pro_active", false);
      }
    }
    setState(() {
      _isPro = false;
      _daysLeft = 0;
    });
  }

  Future<void> _activateKey(String rawKey) async {
    final clean = rawKey.trim().toUpperCase();
    if (activeLicenseKeys.contains(clean)) {
      final prefs = await SharedPreferences.getInstance();
      final expDate = DateTime.now().add(const Duration(days: planValidityDays));
      await prefs.setBool("pro_active", true);
      await prefs.setString("expiry_date", expDate.toIso8601String());
      await _checkLicense();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("👑 Pro Activated for 30 Days! No Ads & No Watermark.")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Invalid Key! Razorpay payment ke baad mili key dalein.")),
        );
      }
    }
  }

  Future<Directory> _getExportDir() async {
    Directory? baseDir = await getExternalStorageDirectory();
    baseDir ??= await getApplicationDocumentsDirectory();
    final outDir = Directory("${baseDir.path}/ViralClipStudio");
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }

  void _showExportAdDialog(VoidCallback onProceed) {
    if (_isPro) {
      onProceed();
      return;
    }

    int secondsLeft = 5;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (secondsLeft > 1) {
                setDialogState(() => secondsLeft--);
              } else {
                t.cancel();
                setDialogState(() => secondsLeft = 0);
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              title: const Text("📢 Sponsored Ad (Free Mode)", style: TextStyle(fontSize: 16, color: Color(0xFF58A6FF))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Free exports include a small watermark. Upgrade to Pro (₹99) for instant ad-free & watermark-free exports!",
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(adNetworkDirectUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text("View Sponsor Offer"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.pop(ctx);
                    setState(() => _selectedIndex = 2);
                  },
                  child: const Text("👑 Remove Ads (₹99)", style: TextStyle(color: Color(0xFFF2CC60))),
                ),
                ElevatedButton(
                  onPressed: secondsLeft == 0
                      ? () {
                          timer?.cancel();
                          Navigator.pop(ctx);
                          onProceed();
                        }
                      : null,
                  child: Text(secondsLeft > 0 ? "Wait ${secondsLeft}s..." : "▶ Export Now"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportViralShort() async {
    if (_shortsVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pehle Gallery se video chunein!")));
      return;
    }
    setState(() {
      _isBusy = true;
      _statusText = "✂️ Rendering 9:16 Viral Short...";
    });

    try {
      final outDir = await _getExportDir();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = "${outDir.path}/Short_$ts.mp4";
      final int durMs = (int.tryParse(_shortsDuration) ?? 30) * 1000;

      final editor = VideoEditorBuilder(videoPath: _shortsVideoPath!)
          .trim(startTimeMs: 0, endTimeMs: durMs)
          .crop(aspectRatio: VideoAspectRatio.ratio9x16);

      final resultPath = await editor.export(outputPath: outPath);

      if (resultPath != null) {
        setState(() => _statusText = "✅ Saved: $resultPath");
      } else {
        setState(() => _statusText = "❌ Render failed. Doosri video try karein.");
      }
    } catch (e) {
      setState(() => _statusText = "❌ Error: $e");
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _exportBeatSync() async {
    if (_beatVideoPath == null || _beatAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video aur Song dono chunein!")));
      return;
    }
    setState(() {
      _isBusy = true;
      _statusText = "🔥 Syncing video with song beats...";
    });

    try {
      final outDir = await _getExportDir();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = "${outDir.path}/BeatSync_$ts.mp4";
      final int durMs = (int.tryParse(_beatDuration) ?? 30) * 1000;

      final editor = VideoEditorBuilder(videoPath: _beatVideoPath!)
          .trim(startTimeMs: 0, endTimeMs: durMs)
          .crop(aspectRatio: VideoAspectRatio.ratio9x16)
          .removeAudio()
          .addAudio(audioPath: _beatAudioPath!);

      final resultPath = await editor.export(outputPath: outPath);

      if (resultPath != null) {
        setState(() => _statusText = "✅ Beat-Sync Saved: $resultPath");
      } else {
        setState(() => _statusText = "❌ Beat-Sync error.");
      }
    } catch (e) {
      setState(() => _statusText = "❌ Error: $e");
    } finally {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildShortsTab(),
      _buildBeatSyncTab(),
      _buildProTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Text("VIRAL CLIP STUDIO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF58A6FF))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isPro ? const Color(0xFF3B2E00) : const Color(0xFF122D1B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isPro ? "👑 PRO (${_daysLeft}d)" : "FREE PLAN",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isPro ? const Color(0xFFF2CC60) : const Color(0xFF3FB950)),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: pages[_selectedIndex]),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusText, style: const TextStyle(fontSize: 12, color: Color(0xFF3FB950), fontWeight: FontWeight.w600)),
                  if (_isBusy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(color: Color(0xFF58A6FF)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF161B22),
        selectedItemColor: const Color(0xFF58A6FF),
        unselectedItemColor: Colors.white60,
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie_creation), label: "Shorts (9:16)"),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: "Beat-Sync"),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: "Pro Pass"),
        ],
      ),
    );
  }

  Widget _buildShortsTab() {
    return ListView(
      children: [
        const Text("🎬 Viral Shorts Auto-Clipper", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Apni video ko 9:16 vertical Shorts me convert karein.", style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: const Color(0xFF21262D)),
          onPressed: () async {
            final res = await FilePicker.platform.pickFiles(type: FileType.video);
            if (res != null && res.files.single.path != null) {
              setState(() => _shortsVideoPath = res.files.single.path);
            }
          },
          icon: const Icon(Icons.video_library),
          label: Text(_shortsVideoPath == null ? "📂 Gallery se Video Chunein" : "✅ Selected: ${_shortsVideoPath!.split('/').last}"),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _hookController,
          decoration: const InputDecoration(
            labelText: "Viral Hook Title / Note",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _shortsDuration,
          decoration: const InputDecoration(labelText: "Clip Duration (Seconds)", border: OutlineInputBorder()),
          items: ["15", "30", "45", "60"].map((e) => DropdownMenuItem(value: e, child: Text("$e Seconds"))).toList(),
          onChanged: (v) => setState(() => _shortsDuration = v ?? "30"),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: const Color(0xFF238636)),
          onPressed: _isBusy ? null : () => _showExportAdDialog(_exportViralShort),
          child: const Text("⚡ Generate Viral Short Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildBeatSyncTab() {
    return ListView(
      children: [
        const Text("🎵 Beat-Sync Montage Editor", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Gameplay ya vlog video par trending song sync karke 9:16 montage banayein.", style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: const Color(0xFF21262D)),
          onPressed: () async {
            final res = await FilePicker.platform.pickFiles(type: FileType.video);
            if (res != null && res.files.single.path != null) {
              setState(() => _beatVideoPath = res.files.single.path);
            }
          },
          icon: const Icon(Icons.videocam),
          label: Text(_beatVideoPath == null ? "🎬 Video File Chunein" : "✅ Video: ${_beatVideoPath!.split('/').last}"),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: const Color(0xFF21262D)),
          onPressed: () async {
            final res = await FilePicker.platform.pickFiles(type: FileType.audio);
            if (res != null && res.files.single.path != null) {
              setState(() => _beatAudioPath = res.files.single.path);
            }
          },
          icon: const Icon(Icons.audiotrack),
          label: Text(_beatAudioPath == null ? "🎶 MP3 / Song File Chunein" : "✅ Song: ${_beatAudioPath!.split('/').last}"),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _beatDuration,
          decoration: const InputDecoration(labelText: "Montage Length", border: OutlineInputBorder()),
          items: ["15", "30", "45", "60"].map((e) => DropdownMenuItem(value: e, child: Text("$e Seconds"))).toList(),
          onChanged: (v) => setState(() => _beatDuration = v ?? "30"),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: const Color(0xFF8957E5)),
          onPressed: _isBusy ? null : () => _showExportAdDialog(_exportBeatSync),
          child: const Text("🔥 Create Beat-Synced Video", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildProTab() {
    return ListView(
      children: [
        const Text("👑 Viral Clip Studio Pro (30 Days)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF2CC60))),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF2CC60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("✔ 100% Watermark-Free HD Exports (30 Days)\n✔ Zero Box Ads (Instant Export)\n✔ Same Key works on PC & Android", style: TextStyle(height: 1.5)),
              const Divider(height: 20),
              const Text("Price: ₹99 / 30 Days", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3FB950))),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: const Color(0xFF1F6FEB)),
                onPressed: () => launchUrl(Uri.parse(razorpayPaymentUrl), mode: LaunchMode.externalApplication),
                child: const Text("💳 Pay ₹99 via Razorpay (UPI / Card)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text("Payment ke baad mila License Key dalein:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _keyController,
          decoration: const InputDecoration(hintText: "e.g. VCS-NOV26-PRO", border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: const Color(0xFF238636)),
          onPressed: () => _activateKey(_keyController.text),
          child: const Text("Activate 30-Day Pro Pass", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}
