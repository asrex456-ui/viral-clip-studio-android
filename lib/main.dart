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
        scaffoldBackgroundColor: const Color(0xFF0D0F18),
        cardColor: const Color(0xFF171A26),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00E5FF),
        ),
      ),
      home: const StudioHomeScreen(),
    );
  }
}

class StudioHomeScreen extends StatefulWidget {
  const StudioHomeScreen({super.key});

  @override
  State<StudioHomeScreen> createState() => _StudioHomeScreenState();
}

class _StudioHomeScreenState extends State<StudioHomeScreen> {
  // Razorpay Config (Live Key approve hone par sirf yahan replace karna hoga)
  static const String _razorpayKeyId = 'rzp_test_U2nQWNx9DbaRJ8';
  // ₹99 + 18% GST = ₹116.82 -> 11682 paise
  static const int _proAmountInPaise = 11682;
  static const int _dailyFreeSplitLimit = 2;

  late Razorpay _razorpay;
  int _currentTab = 0;
  bool _isPro = false;
  int _dailySplitUsed = 0;

  bool _isProcessing = false;
  String _processStatus = '';

  // Tab 1: Auto-Split State
  String? _splitVideoPath;
  String _splitVideoName = 'Koi video select nahi hai';
  int _splitChunkSeconds = 30;
  bool _splitCrop9x16 = true;

  // Tab 2: Clip & Speed State
  String? _editVideoPath;
  String _editVideoName = 'Koi video select nahi hai';
  final TextEditingController _startSecCtrl = TextEditingController(text: '0');
  final TextEditingController _endSecCtrl = TextEditingController(text: '30');
  String _selectedRatio = '9:16';
  double _selectedSpeed = 1.0;
  bool _muteAudio = false;

  // Tab 3A: Rotate / Flip / Compress State
  String? _toolVideoPath;
  String _toolVideoName = 'Koi video select nahi hai';
  int _rotationDeg = 0; // 0, 90, 180, 270
  String _flipMode = 'None'; // None, Horizontal, Vertical
  String _compressMode = 'Original'; // Original, 720p, 480p

  // Tab 3B: Multi-Clip Merger State
  List<String> _mergePaths = [];
  List<String> _mergeNames = [];

  @override
  void initState() {
    super.initState();
    _loadAppPrefs();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _startSecCtrl.dispose();
    _endSecCtrl.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAppPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool('is_pro_unlocked') ?? false;
    final savedDate = prefs.getString('auto_split_date') ?? '';
    final today = _todayKey();

    int usedToday = prefs.getInt('auto_split_count') ?? 0;
    if (savedDate != today) {
      usedToday = 0;
      await prefs.setString('auto_split_date', today);
      await prefs.setInt('auto_split_count', 0);
    }

    if (!mounted) return;
    setState(() {
      _isPro = isPro;
      _dailySplitUsed = usedToday;
    });
  }

  Future<void> _incrementDailySplitUsage() async {
    if (_isPro) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final newCount = _dailySplitUsed + 1;
    await prefs.setString('auto_split_date', today);
    await prefs.setInt('auto_split_count', newCount);
    if (!mounted) return;
    setState(() {
      _dailySplitUsed = newCount;
    });
  }

  Future<void> _unlockPro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_unlocked', true);
    if (!mounted) return;
    setState(() {
      _isPro = true;
    });
  }

  void _openRazorpayCheckout() {
    final options = {
      'key': _razorpayKeyId,
      'amount': _proAmountInPaise,
      'currency': 'INR',
      'name': 'Viral Clip Studio',
      'description': 'Pro Lifetime Unlock (₹99 + 18% GST)',
      'retry': {'enabled': true, 'max_count': 1},
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#6C63FF'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _showSnack('Payment open karne mein error: $e', isError: true);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    await _unlockPro();
    _showSnack('Payment Successful! Viral Clip Studio PRO Unlock ho gaya 🎉');
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

  bool _requirePro(String featureName) {
    if (_isPro) return true;
    _showSnack(
      '$featureName ek PRO feature hai. ₹116.82 mein lifetime unlock karein!',
      isError: true,
    );
    _openRazorpayCheckout();
    return false;
  }

  Future<bool> _ensureGalleryPermission() async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      return await Gal.requestAccess(toAlbum: true);
    }
    return true;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<PlatformFile?> _pickSingleVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      return result.files.single;
    }
    return null;
  }

  // ==================== 1. AUTO-SPLIT LOGIC ====================
  Future<void> _runAutoSplit() async {
    if (_splitVideoPath == null) {
      _showSnack('Pehle koi video select karein!', isError: true);
      return;
    }

    if (!_isPro && _dailySplitUsed >= _dailyFreeSplitLimit) {
      _showSnack(
        'Aaj ke $_dailyFreeSplitLimit Free Auto-Split pure ho gaye! Unlimited ke liye Pro unlock karein.',
        isError: true,
      );
      _openRazorpayCheckout();
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = 'Video duration check ho raha hai...';
    });

    try {
      await _ensureGalleryPermission();

      final meta = await VideoEditorBuilder(videoPath: _splitVideoPath!).getVideoMetadata();
      final int? rawDuration = meta.duration;
      final int totalMs = rawDuration ?? 0;

      if (totalMs <= 0) {
        _showSnack('Video ki length read nahi ho payi.', isError: true);
        return;
      }

      final int chunkMs = _splitChunkSeconds * 1000;
      final List<List<int>> segments = [];
      int start = 0;

      while (start < totalMs) {
        int end = start + chunkMs;
        if (end > totalMs) end = totalMs;
        // Agar aakhri tukda 2 sec se chhota hai aur pehle se parts hain to skip karo
        if ((end - start) < 2000 && segments.isNotEmpty) break;
        segments.add([start, end]);
        start = end;
      }

      int savedCount = 0;
      for (int i = 0; i < segments.length; i++) {
        if (!mounted) return;
        setState(() {
          _processStatus = 'Part ${i + 1} / ${segments.length} export ho raha hai...';
        });

        var editor = VideoEditorBuilder(videoPath: _splitVideoPath!)
            .trim(startTimeMs: segments[i][0], endTimeMs: segments[i][1]);

        if (_splitCrop9x16) {
          editor = editor.crop(aspectRatio: VideoAspectRatio.ratio9x16);
        }

        final outPath = await editor.export();
        if (outPath != null) {
          await Gal.putVideo(outPath, album: 'Viral Clip Studio');
          savedCount++;
        }
      }

      if (savedCount > 0) {
        await _incrementDailySplitUsage();
        _showSnack('$savedCount parts Gallery -> "Viral Clip Studio" mein save ho gaye! 🎬');
      } else {
        _showSnack('Koi bhi part export nahi ho paya.', isError: true);
      }
    } catch (e) {
      _showSnack('Auto-Split error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStatus = '';
        });
      }
    }
  }

  // ==================== 2. CLIP & SPEED LOGIC (PRO) ====================
  Future<void> _runClipAndSpeed() async {
    if (!_requirePro('Clip, Speed & Audio Studio')) return;

    if (_editVideoPath == null) {
      _showSnack('Pehle koi video select karein!', isError: true);
      return;
    }

    final startSec = int.tryParse(_startSecCtrl.text.trim()) ?? 0;
    final endSec = int.tryParse(_endSecCtrl.text.trim()) ?? 30;

    if (endSec <= startSec) {
      _showSnack('End time, Start time se zyada hona chahiye!', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = 'Clip & Speed process ho raha hai...';
    });

    try {
      await _ensureGalleryPermission();

      var editor = VideoEditorBuilder(videoPath: _editVideoPath!)
          .trim(startTimeMs: startSec * 1000, endTimeMs: endSec * 1000);

      if (_selectedRatio == '9:16') {
        editor = editor.crop(aspectRatio: VideoAspectRatio.ratio9x16);
      } else if (_selectedRatio == '1:1') {
        editor = editor.crop(aspectRatio: VideoAspectRatio.ratio1x1);
      } else if (_selectedRatio == '16:9') {
        editor = editor.crop(aspectRatio: VideoAspectRatio.ratio16x9);
      }

      if (_selectedSpeed != 1.0) {
        editor = editor.speed(speed: _selectedSpeed);
      }

      if (_muteAudio) {
        editor = editor.removeAudio();
      }

      final outPath = await editor.export();
      if (outPath != null) {
        await Gal.putVideo(outPath, album: 'Viral Clip Studio');
        _showSnack('Edited video Gallery -> "Viral Clip Studio" mein save ho gaya! ✅');
      } else {
        _showSnack('Video export fail ho gaya.', isError: true);
      }
    } catch (e) {
      _showSnack('Export error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStatus = '';
        });
      }
    }
  }

  // ==================== 3A. ROTATE / FLIP / COMPRESS (PRO) ====================
  Future<void> _runRotateFlipCompress() async {
    if (!_requirePro('Rotate, Mirror & Compress')) return;

    if (_toolVideoPath == null) {
      _showSnack('Pehle koi video select karein!', isError: true);
      return;
    }

    if (_rotationDeg == 0 && _flipMode == 'None' && _compressMode == 'Original') {
      _showSnack('Kam se kam ek option (Rotate, Mirror ya Compress) chuno!', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = 'Video transform & compress ho raha hai...';
    });

    try {
      await _ensureGalleryPermission();

      var editor = VideoEditorBuilder(videoPath: _toolVideoPath!);

      if (_rotationDeg == 90) {
        editor = editor.rotate(degree: RotationDegree.degree90);
      } else if (_rotationDeg == 180) {
        editor = editor.rotate(degree: RotationDegree.degree180);
      } else if (_rotationDeg == 270) {
        editor = editor.rotate(degree: RotationDegree.degree270);
      }

      if (_flipMode == 'Horizontal') {
        editor = editor.flip(flipDirection: FlipDirection.horizontal);
      } else if (_flipMode == 'Vertical') {
        editor = editor.flip(flipDirection: FlipDirection.vertical);
      }

      if (_compressMode == '720p') {
        editor = editor.compress(resolution: VideoResolution.p720);
      } else if (_compressMode == '480p') {
        editor = editor.compress(resolution: VideoResolution.p480);
      }

      final outPath = await editor.export();
      if (outPath != null) {
        await Gal.putVideo(outPath, album: 'Viral Clip Studio');
        _showSnack('Video Gallery -> "Viral Clip Studio" mein save ho gaya! ✅');
      } else {
        _showSnack('Processing fail ho gaya.', isError: true);
      }
    } catch (e) {
      _showSnack('Tool error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStatus = '';
        });
      }
    }
  }

  // ==================== 3B. MULTI-CLIP MERGER (PRO) ====================
  Future<void> _pickMultipleVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null) {
      final paths = <String>[];
      final names = <String>[];
      for (final file in result.files) {
        if (file.path != null) {
          paths.add(file.path!);
          names.add(file.name);
        }
      }
      if (paths.isNotEmpty) {
        setState(() {
          _mergePaths = paths;
          _mergeNames = names;
        });
      }
    }
  }

  Future<void> _runMergeVideos() async {
    if (!_requirePro('Multi-Clip Video Merger')) return;

    if (_mergePaths.length < 2) {
      _showSnack('Merge karne ke liye kam se kam 2 videos select karein!', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _processStatus = '${_mergePaths.length} videos merge ho rahe hain...';
    });

    try {
      await _ensureGalleryPermission();

      final editor = VideoEditorBuilder(videoPath: _mergePaths.first)
          .merge(otherVideoPaths: _mergePaths.sublist(1));

      final outPath = await editor.export();
      if (outPath != null) {
        await Gal.putVideo(outPath, album: 'Viral Clip Studio');
        _showSnack('Merged video Gallery -> "Viral Clip Studio" mein save ho gaya! 🎬');
      } else {
        _showSnack('Merge fail ho gaya.', isError: true);
      }
    } catch (e) {
      _showSnack('Merge error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStatus = '';
        });
      }
    }
  }

  // ==================== UI HELPERS ====================
  Widget _proBadge({String text = 'PRO'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  // ==================== TAB 1 UI: AUTO-SPLIT ====================
  Widget _buildAutoSplitTab() {
    final remaining = (_dailyFreeSplitLimit - _dailySplitUsed).clamp(0, _dailyFreeSplitLimit);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isPro
                ? Colors.amber.withValues(alpha: 0.15)
                : const Color(0xFF6C63FF).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isPro ? Colors.amber : const Color(0xFF6C63FF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _isPro
                      ? 'PRO Active: Unlimited Auto-Split'
                      : 'Free Quota: Aaj $remaining / $_dailyFreeSplitLimit videos bache hain',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (!_isPro)
                TextButton(
                  onPressed: _openRazorpayCheckout,
                  child: const Text('Unlimited', style: TextStyle(color: Colors.amber)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Auto-Split Series (Part 1, 2, 3...)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Lamba video select karo, app apne aap barabar Shorts parts kaat kar Gallery mein save kar dega.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                'Selected: $_splitVideoName',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final f = await _pickSingleVideo();
                        if (f != null) {
                          setState(() {
                            _splitVideoPath = f.path;
                            _splitVideoName = f.name;
                          });
                        }
                      },
                icon: const Icon(Icons.video_file),
                label: const Text('Select Long Video'),
              ),
              const SizedBox(height: 16),
              const Text('Har Part ki Length (Seconds):', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60].map((sec) {
                  return ChoiceChip(
                    label: Text('${sec}s'),
                    selected: _splitChunkSeconds == sec,
                    onSelected: (_) => setState(() => _splitChunkSeconds = sec),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('9:16 Vertical Shorts Crop'),
                subtitle: const Text('Reels & YouTube Shorts ke liye auto-crop'),
                value: _splitCrop9x16,
                onChanged: (v) => setState(() => _splitCrop9x16 = v),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runAutoSplit,
                icon: const Icon(Icons.content_cut),
                label: const Text('Auto-Split & Save All Parts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 2 UI: CLIP & SPEED (PRO) ====================
  Widget _buildClipSpeedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manual Clipper & Speed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (!_isPro) _proBadge(),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Selected: $_editVideoName',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final f = await _pickSingleVideo();
                        if (f != null) {
                          setState(() {
                            _editVideoPath = f.path;
                            _editVideoName = f.name;
                          });
                        }
                      },
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Video'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startSecCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Start (Sec)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endSecCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'End (Sec)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Aspect Ratio (Crop):', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Original', '9:16', '1:1', '16:9'].map((ratio) {
                  return ChoiceChip(
                    label: Text(ratio),
                    selected: _selectedRatio == ratio,
                    onSelected: (_) => setState(() => _selectedRatio = ratio),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Speed Control (Slow-Mo / Viral Fast):', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((spd) {
                  return ChoiceChip(
                    label: Text('${spd}x'),
                    selected: _selectedSpeed == spd,
                    onSelected: (_) => setState(() => _selectedSpeed = spd),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mute / Remove Audio'),
                subtitle: const Text('Video ki original awaaz hatane ke liye'),
                value: _muteAudio,
                onChanged: (v) => setState(() => _muteAudio = v),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runClipAndSpeed,
                icon: Icon(_isPro ? Icons.save_alt : Icons.lock),
                label: Text(_isPro ? 'Export to Gallery' : 'Unlock Pro to Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPro ? const Color(0xFF6C63FF) : Colors.amber,
                  foregroundColor: _isPro ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 3 UI: PRO TOOLS (ROTATE/COMPRESS/MERGE) ====================
  Widget _buildProToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rotate, Mirror & Compress',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (!_isPro) _proBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Selected: $_toolVideoName',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final f = await _pickSingleVideo();
                        if (f != null) {
                          setState(() {
                            _toolVideoPath = f.path;
                            _toolVideoName = f.name;
                          });
                        }
                      },
                icon: const Icon(Icons.video_settings),
                label: const Text('Select Video'),
              ),
              const SizedBox(height: 12),
              const Text('Rotate:', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8,
                children: [0, 90, 180, 270].map((deg) {
                  return ChoiceChip(
                    label: Text(deg == 0 ? 'None' : '$deg°'),
                    selected: _rotationDeg == deg,
                    onSelected: (_) => setState(() => _rotationDeg = deg),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text('Mirror / Flip:', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8,
                children: ['None', 'Horizontal', 'Vertical'].map((mode) {
                  return ChoiceChip(
                    label: Text(mode),
                    selected: _flipMode == mode,
                    onSelected: (_) => setState(() => _flipMode = mode),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text('WhatsApp / Reels Compress:', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8,
                children: ['Original', '720p', '480p'].map((q) {
                  return ChoiceChip(
                    label: Text(q),
                    selected: _compressMode == q,
                    onSelected: (_) => setState(() => _compressMode = q),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runRotateFlipCompress,
                icon: Icon(_isPro ? Icons.auto_fix_high : Icons.lock),
                label: Text(_isPro ? 'Apply & Save to Gallery' : 'Unlock Pro to Use'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPro ? const Color(0xFF6C63FF) : Colors.amber,
                  foregroundColor: _isPro ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Multi-Clip Video Merger',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (!_isPro) _proBadge(),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '2 ya zyada videos select karke ek single video banayein.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 10),
              if (_mergeNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _mergeNames
                        .asMap()
                        .entries
                        .map((e) => Text('${e.key + 1}. ${e.value}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF00E5FF))))
                        .toList(),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pickMultipleVideos,
                      icon: const Icon(Icons.playlist_add),
                      label: Text(_mergePaths.isEmpty
                          ? 'Select 2+ Videos'
                          : '${_mergePaths.length} Videos Selected'),
                    ),
                  ),
                  if (_mergePaths.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() {
                        _mergePaths = [];
                        _mergeNames = [];
                      }),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runMergeVideos,
                icon: Icon(_isPro ? Icons.merge_type : Icons.lock),
                label: Text(_isPro ? 'Merge & Save to Gallery' : 'Unlock Pro to Merge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPro ? const Color(0xFF6C63FF) : Colors.amber,
                  foregroundColor: _isPro ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 4 UI: PRO & UPCOMING LABS ====================
  Widget _buildProTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPro
                  ? [Colors.green.shade800, Colors.teal.shade900]
                  : [const Color(0xFF2D225A), const Color(0xFF171A26)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isPro ? Colors.greenAccent : Colors.amber),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isPro ? 'Viral Clip Studio PRO Active 🎉' : 'Upgrade to Viral Clip Studio PRO',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _isPro
                    ? 'Saare Pro tools lifetime ke liye unlocked hain!'
                    : '₹99 + 18% GST = ₹116.82 (One-Time Payment)',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              const Text('✓ Unlimited Daily Auto-Split (30s / 60s Parts)'),
              const Text('✓ Speed Control (0.5x Slow-Mo se 2.0x Fast)'),
              const Text('✓ Manual 9:16 / 1:1 / 16:9 Shorts Clipper'),
              const Text('✓ Rotate, Mirror Flip & 480p/720p Compress'),
              const Text('✓ Multi-Clip Video Merger & Audio Mute'),
              const SizedBox(height: 16),
              if (!_isPro)
                ElevatedButton.icon(
                  onPressed: _openRazorpayCheckout,
                  icon: const Icon(Icons.star),
                  label: const Text(
                    'Pay ₹116.82 & Unlock Instantly',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Upcoming v2.0 Studio Labs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 10),
        _sectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_motion, color: Color(0xFF00E5FF), size: 32),
            title: const Text('One-Click Photo-to-Video'),
            subtitle: const Text('Photos mila kar premium transitions ke saath Reels banana'),
            trailing: _proBadge(text: 'SOON'),
          ),
        ),
        const SizedBox(height: 10),
        _sectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.closed_caption, color: Color(0xFF6C63FF), size: 32),
            title: const Text('Auto AI Viral Captions'),
            subtitle: const Text('Hindi & Hinglish auto subtitles for Shorts/Reels'),
            trailing: _proBadge(text: 'SOON'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildAutoSplitTab(),
      _buildClipSpeedTab(),
      _buildProToolsTab(),
      _buildProTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viral Clip Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF171A26),
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
                    icon: const Icon(Icons.star, size: 15),
                    label: const Text('Go Pro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isProcessing)
            Container(
              width: double.infinity,
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _processStatus.isEmpty ? 'Processing...' : _processStatus,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: pages[_currentTab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF171A26),
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.content_cut), label: 'Auto-Split'),
          NavigationDestination(icon: Icon(Icons.speed), label: 'Clip & Speed'),
          NavigationDestination(icon: Icon(Icons.build_circle), label: 'Pro Tools'),
          NavigationDestination(icon: Icon(Icons.workspace_premium), label: 'Pro'),
        ],
      ),
    );
  }
}
