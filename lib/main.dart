import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:gal/gal.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ViralClipStudioApp());
}

class ViralClipStudioApp extends StatelessWidget {
  const ViralClipStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viral Clip Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00E5FF),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Razorpay Key ID (Live key approve hone par sirf yahan replace karna hoga)
  static const String _razorpayKeyId = 'rzp_test_U2nQWNx9DbaRJ8';
  // ₹99 + 18% GST = ₹116.82 -> 11682 paise
  static const int _proAmountInPaise = 11682;

  late Razorpay _razorpay;
  bool _isPro = false;
  bool _isProcessing = false;
  String? _selectedVideoPath;
  String _statusMessage = 'Koi video select karein edit karne ke liye.';

  final TextEditingController _startSecController = TextEditingController(text: '0');
  final TextEditingController _endSecController = TextEditingController(text: '15');
  bool _cropToShorts = true;

  @override
  void initState() {
    super.initState();
    _loadProStatus();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _startSecController.dispose();
    _endSecController.dispose();
    super.dispose();
  }

  Future<void> _loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPro = prefs.getBool('is_pro_unlocked') ?? false;
    });
  }

  Future<void> _unlockPro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_unlocked', true);
    setState(() {
      _isPro = true;
    });
  }

  void _openRazorpayCheckout() {
    var options = {
      'key': _razorpayKeyId,
      'amount': _proAmountInPaise,
      'currency': 'INR',
      'name': 'Viral Clip Studio',
      'description': 'Pro Lifetime Unlock (₹99 + 18% GST)',
      'retry': {'enabled': true, 'max_count': 1},
      'prefill': {
        'contact': '',
        'email': '',
      },
      'theme': {
        'color': '#6C63FF',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _showSnack('Payment open karne mein error: $e', isError: true);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    await _unlockPro();
    _showSnack('Payment Successful! Viral Clip Studio Pro Unlock ho gaya 🎉');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showSnack(
      'Payment cancel ya fail ho gaya: ${response.message ?? "Try again"}',
      isError: true,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnack('External Wallet selected: ${response.walletName}');
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideoPath = result.files.single.path;
        _statusMessage = 'Video selected: ${result.files.single.name}';
      });
    }
  }

  Future<void> _exportAndSaveToGallery() async {
    if (_selectedVideoPath == null) {
      _showSnack('Pehle koi video select karein!', isError: true);
      return;
    }

    final startSec = int.tryParse(_startSecController.text.trim()) ?? 0;
    final endSec = int.tryParse(_endSecController.text.trim()) ?? 15;

    if (endSec <= startSec) {
      _showSnack('End time, Start time se zyada hona chahiye!', isError: true);
      return;
    }

    // Free users ke liye 15 sec limit, Pro ke liye unlimited
    if (!_isPro && (endSec - startSec) > 15) {
      _showSnack(
        'Free version mein max 15 sec clip ban sakti hai. Pro unlock karein!',
        isError: true,
      );
      _openRazorpayCheckout();
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Video process ho raha hai...';
    });

    try {
      // Gallery permission request
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: true);
      }

      var editor = VideoEditorBuilder(videoPath: _selectedVideoPath!)
          .trim(startTimeMs: startSec * 1000, endTimeMs: endSec * 1000);

      if (_cropToShorts) {
        editor = editor.crop(aspectRatio: VideoAspectRatio.ratio9x16);
      }

      final outputPath = await editor.export();

      if (outputPath != null) {
        // Seedha phone ki Gallery -> "Viral Clip Studio" album mein save karega
        await Gal.putVideo(outputPath, album: 'Viral Clip Studio');
        setState(() {
          _statusMessage = 'Saved to Gallery -> Viral Clip Studio ✅';
        });
        _showSnack('Video Gallery mein "Viral Clip Studio" album mein save ho gaya! 🎬');
      } else {
        setState(() {
          _statusMessage = 'Export fail ho gaya.';
        });
        _showSnack('Video export nahi ho paya.', isError: true);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      _showSnack('Error aaya: $e', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viral Clip Studio'),
        backgroundColor: const Color(0xFF1A1D2B),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _isPro
                ? const Chip(
                    label: Text('PRO', style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.amber,
                    labelStyle: TextStyle(color: Colors.black),
                  )
                : ElevatedButton.icon(
                    onPressed: _openRazorpayCheckout,
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Go Pro ₹116.82'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.video_library, size: 48, color: Color(0xFF6C63FF)),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickVideo,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Video'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startSecController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start (Seconds)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endSecController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'End (Seconds)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('9:16 Shorts / Reels Crop'),
              subtitle: const Text('YouTube Shorts & Instagram Reels ke liye'),
              value: _cropToShorts,
              onChanged: (val) => setState(() => _cropToShorts = val),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _exportAndSaveToGallery,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_alt),
              label: Text(
                _isProcessing ? 'Exporting to Gallery...' : 'Export & Save to Gallery',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (!_isPro)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Unlock Viral Clip Studio Pro',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '₹99 + 18% GST = ₹116.82 (One-Time)\nUnlimited Clip Length • Instant Auto-Unlock',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _openRazorpayCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Pay ₹116.82 & Unlock Pro'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
