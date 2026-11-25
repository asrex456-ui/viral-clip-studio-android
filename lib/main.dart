import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ViralClipStudioApp());
}

// ============================================================================
// THEME & COLORS
// ============================================================================
class AppColors {
  static const bg = Color(0xFF0A0A14);
  static const surface = Color(0xFF141426);
  static const surfaceLight = Color(0xFF1E1E38);
  static const purple = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const cyan = Color(0xFF06B6D4);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const textMuted = Color(0xFF9CA3AF);
}

class ViralClipStudioApp extends StatelessWidget {
  const ViralClipStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viral Clip Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.purple,
          secondary: AppColors.pink,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.surfaceLight,
            disabledForegroundColor: AppColors.textMuted,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.purple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceLight,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

// ============================================================================
// STORAGE & FFMPEG HELPERS
// ============================================================================
class StudioStorage {
  static Future<void> requestPermissions() async {
    await [
      Permission.videos,
      Permission.photos,
      Permission.audio,
      Permission.storage,
    ].request();
  }

  static Future<Directory> getExportDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/ViralClipExports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> newOutputPath(String prefix) async {
    final dir = await getExportDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${prefix}_$ts.mp4';
  }

  static Future<String?> mirrorToDownloads(String sourcePath) async {
    try {
      final downloadsDir =
          Directory('/storage/emulated/0/Download/ViralClipStudio');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final name = sourcePath.split('/').last;
      final dest = '${downloadsDir.path}/$name';
      await File(sourcePath).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  static Future<List<File>> listExports() async {
    final dir = await getExportDir();
    final items = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.mp4'))
        .toList();
    items.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return items;
  }

  static Future<void> clearTempCache() async {
    final temp = await getTemporaryDirectory();
    if (await temp.exists()) {
      for (final entity in temp.listSync()) {
        try {
          entity.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mins:$secs';
    return '$mins:$secs';
  }

  static String formatSeconds(double seconds) {
    return formatDuration(Duration(seconds: seconds.round()));
  }

  static String formatFileSize(File file) {
    final bytes = file.lengthSync();
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

// ============================================================================
// MAIN SHELL (4 BOTTOM TABS)
// ============================================================================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _projectsRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    StudioStorage.requestPermissions();
  }

  void _goHome() {
    setState(() => _index = 0);
  }

  void _openProjects() {
    setState(() {
      _projectsRefreshKey++;
      _index = 1;
    });
  }

  Future<void> _pushTool(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
    setState(() => _projectsRefreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        onOpenYoutube: () => _pushTool(const YoutubeClipperScreen()),
        onOpenViceGaming: () => _pushTool(const ViceGamingScreen()),
        onOpenAutoSplit: () => _pushTool(const AutoSplitScreen()),
        onOpenStreamerSplit: () => _pushTool(const StreamerSplitScreen()),
        onOpenProEditor: () => _pushTool(const ProEditorScreen()),
        onOpenMultiMerge: () => _pushTool(const MultiMergeScreen()),
        onOpenPhotoReels: () => _pushTool(const PhotoReelsScreen()),
      ),
      ProjectsTab(
        key: ValueKey(_projectsRefreshKey),
        onCreateNew: _goHome,
      ),
      PacksTab(
        onSelectEffect: (effectName) =>
            _pushTool(ProEditorScreen(initialEffect: effectName)),
      ),
      MeTab(onOpenProjects: _openProjects),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              'Viral Clip ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            Text(
              'Studio',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.pink,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.green),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science, size: 14, color: AppColors.green),
                SizedBox(width: 5),
                Text(
                  'TEST v2.3',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.purple.withAlpha(70),
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            if (i == 1) _projectsRefreshKey++;
            _index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.home, color: Colors.white),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.folder, color: Colors.white),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.auto_awesome, color: Colors.white),
            label: 'Packs',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.person, color: Colors.white),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: HOME TAB
// ============================================================================
class HomeTab extends StatelessWidget {
  final VoidCallback onOpenYoutube;
  final VoidCallback onOpenViceGaming;
  final VoidCallback onOpenAutoSplit;
  final VoidCallback onOpenStreamerSplit;
  final VoidCallback onOpenProEditor;
  final VoidCallback onOpenMultiMerge;
  final VoidCallback onOpenPhotoReels;

  const HomeTab({
    super.key,
    required this.onOpenYoutube,
    required this.onOpenViceGaming,
    required this.onOpenAutoSplit,
    required this.onOpenStreamerSplit,
    required this.onOpenProEditor,
    required this.onOpenMultiMerge,
    required this.onOpenPhotoReels,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Featured NEW Card: YouTube Link Clipper
        GestureDetector(
          onTap: onOpenYoutube,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.red.withAlpha(65),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(80),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'NEW • DIRECT APK EXCLUSIVE',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'YouTube Link Clipper',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Link paste karo -> 30s/60s Viral Clip ya Full Video download karo',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Vice Gaming Clipper Banner
        GestureDetector(
          onTap: onOpenViceGaming,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFFEC4899)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_esports, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vice Gaming Clipper',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Vice Neon Grade + Bass Boost + 9:16 Hype Export',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'OPEN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Studio Tools (100% Unlocked)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _toolCard(
              icon: Icons.content_cut,
              color: AppColors.cyan,
              title: 'Auto-Split Shorts',
              subtitle: '30s / 60s parts auto cut',
              onTap: onOpenAutoSplit,
            ),
            _toolCard(
              icon: Icons.splitscreen,
              color: AppColors.pink,
              title: 'Streamer Split',
              subtitle: 'Facecam Top + Gameplay',
              onTap: onOpenStreamerSplit,
            ),
            _toolCard(
              icon: Icons.tune,
              color: AppColors.purple,
              title: 'Pro Video Editor',
              subtitle: 'Trim, Crop, Speed, FX',
              onTap: onOpenProEditor,
            ),
            _toolCard(
              icon: Icons.merge_type,
              color: Colors.orangeAccent,
              title: 'Multi-Clip Merger',
              subtitle: '2+ videos ek mein jodo',
              onTap: onOpenMultiMerge,
            ),
            _toolCard(
              icon: Icons.photo_library,
              color: AppColors.green,
              title: 'Photo Reels',
              subtitle: 'Photos se 9:16 video',
              onTap: onOpenPhotoReels,
            ),
            _toolCard(
              icon: Icons.link,
              color: AppColors.red,
              title: 'YT Downloader',
              subtitle: 'Direct MP4 / Clip save',
              onTap: onOpenYoutube,
            ),
          ],
        ),
      ],
    );
  }

  Widget _toolCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TOOL 1: YOUTUBE LINK CLIPPER & DOWNLOADER (NEW)
// ============================================================================
class YoutubeClipperScreen extends StatefulWidget {
  const YoutubeClipperScreen({super.key});

  @override
  State<YoutubeClipperScreen> createState() => _YoutubeClipperScreenState();
}

class _YoutubeClipperScreenState extends State<YoutubeClipperScreen> {
  final TextEditingController _urlCtrl = TextEditingController();

  bool _loadingInfo = false;
  bool _processing = false;
  String _statusText = '';
  double _downloadProgress = 0;

  Video? _video;
  StreamInfo? _selectedStream;
  double _totalSeconds = 60;
  RangeValues _clipRange = const RangeValues(0, 30);

  String _clipMode = '30s';
  String _aspectMode = '9:16_crop';

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() => _urlCtrl.text = data.text!.trim());
    }
  }

  Future<void> _fetchVideoInfo() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) {
      _showSnack('Pehle YouTube link paste karo bhai');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loadingInfo = true;
      _video = null;
      _selectedStream = null;
      _statusText = 'YouTube video details nikal rahe hain...';
    });

    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(rawUrl);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      StreamInfo? stream;
      if (manifest.muxed.isNotEmpty) {
        stream = manifest.muxed.withHighestBitrate();
      } else if (manifest.videoOnly.isNotEmpty) {
        stream = manifest.videoOnly.withHighestBitrate();
      }

      if (stream == null) {
        throw Exception('Koi downloadable stream nahi mila.');
      }

      final secs = (video.duration?.inSeconds ?? 60).toDouble();
      final safeTotal = secs < 2 ? 2.0 : secs;
      final endDefault = safeTotal > 30 ? 30.0 : safeTotal;

      if (!mounted) return;
      setState(() {
        _video = video;
        _selectedStream = stream;
        _totalSeconds = safeTotal;
        _clipRange = RangeValues(0, endDefault);
        _clipMode = safeTotal >= 30 ? '30s' : 'full';
        _statusText = '';
      });
    } catch (e) {
      if (mounted) {
        _showSnack('Video load fail: ${e.toString()}');
        setState(() => _statusText = '');
      }
    } finally {
      yt.close();
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  void _applyClipPreset(String mode) {
    setState(() {
      _clipMode = mode;
      final start = _clipRange.start;
      if (mode == '30s') {
        final end = (start + 30).clamp(1.0, _totalSeconds);
        _clipRange = RangeValues(start >= end ? 0 : start, end);
      } else if (mode == '60s') {
        final end = (start + 60).clamp(1.0, _totalSeconds);
        _clipRange = RangeValues(start >= end ? 0 : start, end);
      } else if (mode == 'full') {
        _clipRange = RangeValues(0, _totalSeconds);
      }
    });
  }

  Future<void> _downloadAndClip() async {
    if (_video == null || _selectedStream == null) return;

    setState(() {
      _processing = true;
      _downloadProgress = 0;
      _statusText = 'Step 1/2: YouTube video download ho raha hai...';
    });

    final yt = YoutubeExplode();
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
          '${tempDir.path}/yt_raw_${DateTime.now().millisecondsSinceEpoch}.mp4');

      final stream = yt.videos.streamsClient.get(_selectedStream!);
      final totalBytes = _selectedStream!.size.totalBytes;
      int received = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() {
            _downloadProgress = (received / totalBytes).clamp(0.0, 1.0);
            final pct = (_downloadProgress * 100).toStringAsFixed(0);
            _statusText = 'Step 1/2: Downloading... $pct%';
          });
        }
      }
      await sink.flush();
      await sink.close();

      final outputPath = await StudioStorage.newOutputPath('yt_clip');
      final isFullOriginal = _clipMode == 'full' && _aspectMode == 'original';

      if (isFullOriginal) {
        if (mounted) {
          setState(
              () => _statusText = 'Step 2/2: Full video save ho raha hai...');
        }
        await tempFile.copy(outputPath);
      } else {
        if (mounted) {
          setState(() =>
              _statusText = 'Step 2/2: Viral clip cut & render ho raha hai...');
        }

        final startSec = _clipRange.start.toStringAsFixed(1);
        final durationSec = (_clipRange.end - _clipRange.start)
            .clamp(1.0, _totalSeconds)
            .toStringAsFixed(1);

        String cmd;
        if (_aspectMode == 'original') {
          cmd =
              '-y -ss $startSec -i "${tempFile.path}" -t $durationSec -c copy "$outputPath"';
        } else if (_aspectMode == '9:16_crop') {
          cmd = '-y -ss $startSec -i "${tempFile.path}" -t $durationSec '
              '-vf "crop=ih*9/16:ih,scale=720:1280" '
              '-c:v mpeg4 -q:v 3 -c:a aac "$outputPath"';
        } else {
          cmd = '-y -ss $startSec -i "${tempFile.path}" -t $durationSec '
              '-filter_complex "[0:v]scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,boxblur=20:5[bg];'
              '[0:v]scale=720:1280:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2" '
              '-c:v mpeg4 -q:v 3 -c:a aac "$outputPath"';
        }

        final session = await FFmpegKit.execute(cmd);
        final rc = await session.getReturnCode();
        if (!ReturnCode.isSuccess(rc)) {
          final fallbackCmd =
              '-y -ss $startSec -i "${tempFile.path}" -t $durationSec -c:v mpeg4 -q:v 4 -c:a aac "$outputPath"';
          final fbSession = await FFmpegKit.execute(fallbackCmd);
          final fbRc = await fbSession.getReturnCode();
          if (!ReturnCode.isSuccess(fbRc)) {
            throw Exception('FFmpeg render fail hua.');
          }
        }
      }

      final downloadCopy = await StudioStorage.mirrorToDownloads(outputPath);

      if (!mounted) return;
      _showExportSuccessDialog(context, outputPath, downloadCopy);
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}');
    } finally {
      yt.close();
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _processing = false;
          _statusText = '';
          _downloadProgress = 0;
        });
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Link Clipper')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'YouTube Video ya Shorts ka link daalo:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'https://youtu.be/... ya youtube.com/watch?v=...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste, color: AppColors.cyan),
                      tooltip: 'Paste',
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_loadingInfo || _processing) ? null : _fetchVideoInfo,
              icon: _loadingInfo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(_loadingInfo
                  ? 'Video Check Ho Raha Hai...'
                  : 'Load YouTube Video'),
            ),
          ),
          if (_video != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.purple.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _video!.thumbnails.highResUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: AppColors.surfaceLight,
                        child: const Center(
                          child: Icon(Icons.ondemand_video,
                              size: 48, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _video!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Channel: ${_video!.author} • Length: ${StudioStorage.formatSeconds(_totalSeconds)} • '
                    'Size: ${_selectedStream!.size.totalMegaBytes.toStringAsFixed(1)} MB',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '1. Clip Length Chuno',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choiceChip('30s Viral', _clipMode == '30s',
                    () => _applyClipPreset('30s')),
                _choiceChip('60s Viral', _clipMode == '60s',
                    () => _applyClipPreset('60s')),
                _choiceChip('Custom Cut', _clipMode == 'custom',
                    () => _applyClipPreset('custom')),
                _choiceChip('Full Video', _clipMode == 'full',
                    () => _applyClipPreset('full')),
              ],
            ),
            if (_clipMode != 'full') ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Start: ${StudioStorage.formatSeconds(_clipRange.start)}',
                    style: const TextStyle(
                        color: AppColors.cyan, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Clip: ${(_clipRange.end - _clipRange.start).round()} sec',
                    style: const TextStyle(
                        color: AppColors.pink, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'End: ${StudioStorage.formatSeconds(_clipRange.end)}',
                    style: const TextStyle(
                        color: AppColors.cyan, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              RangeSlider(
                values: _clipRange,
                min: 0,
                max: _totalSeconds,
                activeColor: AppColors.pink,
                inactiveColor: AppColors.surfaceLight,
                onChanged: (v) {
                  if (v.end - v.start >= 1.0) {
                    setState(() {
                      _clipRange = v;
                      _clipMode = 'custom';
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '2. Format / Ratio Chuno',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choiceChip('9:16 Shorts Crop', _aspectMode == '9:16_crop',
                    () => setState(() => _aspectMode = '9:16_crop')),
                _choiceChip('9:16 Blur BG', _aspectMode == '9:16_blur',
                    () => setState(() => _aspectMode = '9:16_blur')),
                _choiceChip('16:9 Original', _aspectMode == 'original',
                    () => setState(() => _aspectMode = 'original')),
              ],
            ),
            const SizedBox(height: 22),
            if (_processing) ...[
              LinearProgressIndicator(
                value: _downloadProgress > 0 && _downloadProgress < 1
                    ? _downloadProgress
                    : null,
                color: AppColors.pink,
                backgroundColor: AppColors.surfaceLight,
                minHeight: 8,
              ),
              const SizedBox(height: 10),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.cyan, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  foregroundColor: Colors.white,
                ),
                onPressed: _processing ? null : _downloadAndClip,
                icon: const Icon(Icons.download_for_offline),
                label: Text(_clipMode == 'full'
                    ? 'Download Full Video'
                    : 'Cut & Save Viral Clip'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.purple,
      backgroundColor: AppColors.surfaceLight,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

// ============================================================================
// TOOL 2: VICE GAMING CLIPPER
// ============================================================================
class ViceGamingScreen extends StatefulWidget {
  const ViceGamingScreen({super.key});

  @override
  State<ViceGamingScreen> createState() => _ViceGamingScreenState();
}

class _ViceGamingScreenState extends State<ViceGamingScreen> {
  String? _videoPath;
  bool _viceNeon = true;
  bool _bassBoost = true;
  bool _verticalCrop = true;
  bool _actionSpeed = false;
  bool _processing = false;

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res != null && res.files.single.path != null) {
      setState(() => _videoPath = res.files.single.path);
    }
  }

  Future<void> _export() async {
    if (_videoPath == null) return;
    setState(() => _processing = true);
    try {
      final out = await StudioStorage.newOutputPath('vice_gaming');
      final vFilters = <String>[];
      final aFilters = <String>[];

      if (_verticalCrop) {
        vFilters.add('crop=ih*9/16:ih,scale=720:1280');
      }
      if (_viceNeon) {
        vFilters.add('eq=contrast=1.18:saturation=1.45:brightness=0.03');
      }
      if (_actionSpeed) {
        vFilters.add('setpts=0.87*PTS');
        aFilters.add('atempo=1.15');
      }
      if (_bassBoost) {
        aFilters.add('bass=g=8:f=110:w=0.6');
      }

      final vfArg = vFilters.isNotEmpty ? '-vf "${vFilters.join(',')}"' : '';
      final afArg = aFilters.isNotEmpty ? '-af "${aFilters.join(',')}"' : '';

      final cmd =
          '-y -i "$_videoPath" $vfArg $afArg -c:v mpeg4 -q:v 3 -c:a aac "$out"';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();

      if (!mounted) return;
      if (ReturnCode.isSuccess(rc)) {
        final dl = await StudioStorage.mirrorToDownloads(out);
        if (!mounted) return;
        _showExportSuccessDialog(context, out, dl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gaming clip export fail hua.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vice Gaming Clipper')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _processing ? null : _pickVideo,
            icon: const Icon(Icons.video_library),
            label: Text(_videoPath == null
                ? 'Gameplay Video Chuno'
                : 'Change Gameplay Video'),
          ),
          if (_videoPath != null) ...[
            const SizedBox(height: 10),
            Text(
              'Selected: ${_videoPath!.split('/').last}',
              style: const TextStyle(color: AppColors.cyan, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Vice Neon Color Grade'),
            subtitle: const Text('High contrast neon gaming look'),
            value: _viceNeon,
            activeColor: AppColors.pink,
            onChanged: (v) => setState(() => _viceNeon = v),
          ),
          SwitchListTile(
            title: const Text('Bass Boost Punch SFX'),
            subtitle: const Text('Heavy gaming bass boost'),
            value: _bassBoost,
            activeColor: AppColors.pink,
            onChanged: (v) => setState(() => _bassBoost = v),
          ),
          SwitchListTile(
            title: const Text('9:16 Vertical Shorts Crop'),
            subtitle: const Text('Center action crop for Reels/Shorts'),
            value: _verticalCrop,
            activeColor: AppColors.pink,
            onChanged: (v) => setState(() => _verticalCrop = v),
          ),
          SwitchListTile(
            title: const Text('1.15x Fast Action Speed'),
            subtitle: const Text('High-retention fast gameplay'),
            value: _actionSpeed,
            activeColor: AppColors.pink,
            onChanged: (v) => setState(() => _actionSpeed = v),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
            ),
            onPressed: (_videoPath == null || _processing) ? null : _export,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt),
            label: Text(
                _processing ? 'Rendering Gaming Clip...' : 'Export Vice Clip'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 3: AUTO-SPLIT SHORTS (30s / 60s)
// ============================================================================
class AutoSplitScreen extends StatefulWidget {
  const AutoSplitScreen({super.key});

  @override
  State<AutoSplitScreen> createState() => _AutoSplitScreenState();
}

class _AutoSplitScreenState extends State<AutoSplitScreen> {
  String? _videoPath;
  int _partSeconds = 30;
  bool _vertical = true;
  bool _processing = false;

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res != null && res.files.single.path != null) {
      setState(() => _videoPath = res.files.single.path);
    }
  }

  Future<void> _splitVideo() async {
    if (_videoPath == null) return;
    setState(() => _processing = true);

    try {
      final exportDir = await StudioStorage.getExportDir();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final pattern = '${exportDir.path}/split_${ts}_part%02d.mp4';

      final cmd = _vertical
          ? '-y -i "$_videoPath" -vf "crop=ih*9/16:ih,scale=720:1280" '
              '-c:v mpeg4 -q:v 3 -c:a aac -f segment -segment_time $_partSeconds '
              '-reset_timestamps 1 "$pattern"'
          : '-y -i "$_videoPath" -c copy -map 0 -f segment '
              '-segment_time $_partSeconds -reset_timestamps 1 "$pattern"';

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();

      if (!mounted) return;
      if (ReturnCode.isSuccess(rc)) {
        final created = exportDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('split_${ts}_part'))
            .toList();
        for (final f in created) {
          await StudioStorage.mirrorToDownloads(f.path);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${created.length} parts ban kar Projects tab mein save ho gaye!'),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-Split fail hua.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Split Shorts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _processing ? null : _pickVideo,
            icon: const Icon(Icons.video_file),
            label: Text(
                _videoPath == null ? 'Long Video Select Karo' : 'Video Badlo'),
          ),
          if (_videoPath != null) ...[
            const SizedBox(height: 10),
            Text(
              'Selected: ${_videoPath!.split('/').last}',
              style: const TextStyle(color: AppColors.cyan),
            ),
          ],
          const SizedBox(height: 18),
          const Text('Har Part Ki Length:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [15, 30, 60].map((sec) {
              final selected = _partSeconds == sec;
              return ChoiceChip(
                label: Text('${sec}s Parts'),
                selected: selected,
                selectedColor: AppColors.purple,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: const TextStyle(color: Colors.white),
                onSelected: (_) => setState(() => _partSeconds = sec),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            title: const Text('Auto 9:16 Vertical Shorts Crop'),
            value: _vertical,
            activeColor: AppColors.purple,
            onChanged: (v) => setState(() => _vertical = v),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: (_videoPath == null || _processing) ? null : _splitVideo,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.content_cut),
            label:
                Text(_processing ? 'Splitting Video...' : 'Start Auto-Split'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 4: STREAMER SPLIT (FACECAM TOP + GAMEPLAY BOTTOM)
// ============================================================================
class StreamerSplitScreen extends StatefulWidget {
  const StreamerSplitScreen({super.key});

  @override
  State<StreamerSplitScreen> createState() => _StreamerSplitScreenState();
}

class _StreamerSplitScreenState extends State<StreamerSplitScreen> {
  String? _videoPath;
  String _camPos = 'top_left';
  bool _processing = false;

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res != null && res.files.single.path != null) {
      setState(() => _videoPath = res.files.single.path);
    }
  }

  Future<void> _exportSplit() async {
    if (_videoPath == null) return;
    setState(() => _processing = true);

    try {
      final out = await StudioStorage.newOutputPath('streamer_split');
      String camCrop;
      switch (_camPos) {
        case 'top_right':
          camCrop = 'crop=iw*0.30:ih*0.32:iw*0.70:0';
          break;
        case 'bottom_left':
          camCrop = 'crop=iw*0.30:ih*0.32:0:ih*0.68';
          break;
        case 'bottom_right':
          camCrop = 'crop=iw*0.30:ih*0.32:iw*0.70:ih*0.68';
          break;
        default:
          camCrop = 'crop=iw*0.30:ih*0.32:0:0';
      }

      final cmd = '-y -i "$_videoPath" '
          '-filter_complex "[0:v]$camCrop,scale=720:460:force_original_aspect_ratio=increase,crop=720:460[cam];'
          '[0:v]crop=ih*0.90:ih,scale=720:820:force_original_aspect_ratio=increase,crop=720:820[game];'
          '[cam][game]vstack=inputs=2[v]" '
          '-map "[v]" -map 0:a? -c:v mpeg4 -q:v 3 -c:a aac "$out"';

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();

      if (!mounted) return;
      if (ReturnCode.isSuccess(rc)) {
        final dl = await StudioStorage.mirrorToDownloads(out);
        if (!mounted) return;
        _showExportSuccessDialog(context, out, dl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Streamer Split export fail hua.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = {
      'top_left': 'Top-Left Facecam',
      'top_right': 'Top-Right Facecam',
      'bottom_left': 'Bottom-Left Facecam',
      'bottom_right': 'Bottom-Right Facecam',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Streamer Split (9:16)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _processing ? null : _pickVideo,
            icon: const Icon(Icons.video_library),
            label: Text(
                _videoPath == null ? 'Stream Video Chuno' : 'Video Change Karo'),
          ),
          if (_videoPath != null) ...[
            const SizedBox(height: 10),
            Text('Selected: ${_videoPath!.split('/').last}',
                style: const TextStyle(color: AppColors.cyan)),
          ],
          const SizedBox(height: 18),
          const Text('Original Video Mein Facecam Kahan Hai?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: positions.entries.map((e) {
              final sel = _camPos == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: sel,
                selectedColor: AppColors.pink,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: const TextStyle(color: Colors.white),
                onSelected: (_) => setState(() => _camPos = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
            ),
            onPressed:
                (_videoPath == null || _processing) ? null : _exportSplit,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.splitscreen),
            label: Text(_processing
                ? 'Rendering Facecam + Gameplay...'
                : 'Export Streamer Split'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 5: PRO VIDEO EDITOR (TRIM, CROP, SPEED, EFFECTS, MUTE)
// ============================================================================
class ProEditorScreen extends StatefulWidget {
  final String? initialEffect;
  const ProEditorScreen({super.key, this.initialEffect});

  @override
  State<ProEditorScreen> createState() => _ProEditorScreenState();
}

class _ProEditorScreenState extends State<ProEditorScreen> {
  String? _videoPath;
  final TextEditingController _startCtrl = TextEditingController(text: '0');
  final TextEditingController _endCtrl = TextEditingController(text: '');

  String _ratio = 'Original';
  double _speed = 1.0;
  late String _effect;
  bool _mute = false;
  bool _processing = false;

  static const List<String> effectsList = [
    'Original',
    'Vice Neon',
    'Miami Sunset',
    'Noir B&W',
    'Vintage',
    'Cinematic',
    'HDR Pop',
    'Cyber Cyan',
    'Warm Glow',
    'Mirror Flip',
  ];

  @override
  void initState() {
    super.initState();
    _effect = widget.initialEffect ?? 'Original';
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res != null && res.files.single.path != null) {
      setState(() => _videoPath = res.files.single.path);
    }
  }

  String? _effectFilter(String name) {
    switch (name) {
      case 'Vice Neon':
        return 'eq=contrast=1.2:saturation=1.5:brightness=0.04';
      case 'Miami Sunset':
        return 'colorbalance=rs=0.25:gs=-0.05:bs=-0.15,eq=saturation=1.3';
      case 'Noir B&W':
        return 'hue=s=0,eq=contrast=1.25';
      case 'Vintage':
        return 'curves=vintage';
      case 'Cinematic':
        return 'eq=contrast=1.15:saturation=0.88:gamma=0.95';
      case 'HDR Pop':
        return 'eq=contrast=1.25:saturation=1.35';
      case 'Cyber Cyan':
        return 'colorbalance=rs=-0.15:gs=0.1:bs=0.25,eq=contrast=1.15';
      case 'Warm Glow':
        return 'colorbalance=rs=0.18:gs=0.06:bs=-0.1';
      case 'Mirror Flip':
        return 'hflip';
      default:
        return null;
    }
  }

  Future<void> _export() async {
    if (_videoPath == null) return;
    setState(() => _processing = true);

    try {
      final out = await StudioStorage.newOutputPath('pro_edit');
      final vFilters = <String>[];
      final aFilters = <String>[];

      if (_ratio == '9:16') {
        vFilters.add('crop=ih*9/16:ih,scale=720:1280');
      } else if (_ratio == '1:1') {
        vFilters.add('crop=min(iw\\,ih):min(iw\\,ih),scale=720:720');
      } else if (_ratio == '16:9') {
        vFilters.add(
            'scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2');
      }

      final fx = _effectFilter(_effect);
      if (fx != null) vFilters.add(fx);

      if (_speed != 1.0) {
        final pts = (1.0 / _speed).toStringAsFixed(2);
        vFilters.add('setpts=$pts*PTS');
        if (!_mute) aFilters.add('atempo=$_speed');
      }

      final start = double.tryParse(_startCtrl.text.trim()) ?? 0;
      final end = double.tryParse(_endCtrl.text.trim());

      final trimArgs = StringBuffer();
      if (start > 0) trimArgs.write('-ss $start ');
      if (end != null && end > start) {
        trimArgs.write('-t ${(end - start).toStringAsFixed(1)} ');
      }

      final vfArg = vFilters.isNotEmpty ? '-vf "${vFilters.join(',')}"' : '';
      final audioArg = _mute
          ? '-an'
          : (aFilters.isNotEmpty
              ? '-af "${aFilters.join(',')}" -c:a aac'
              : '-c:a aac');

      final cmd =
          '-y ${trimArgs.toString()}-i "$_videoPath" $vfArg -c:v mpeg4 -q:v 3 $audioArg "$out"';

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();

      if (!mounted) return;
      if (ReturnCode.isSuccess(rc)) {
        final dl = await StudioStorage.mirrorToDownloads(out);
        if (!mounted) return;
        _showExportSuccessDialog(context, out, dl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export fail hua — inputs check karo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pro Video Editor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _processing ? null : _pickVideo,
            icon: const Icon(Icons.video_collection),
            label: Text(
                _videoPath == null ? 'Gallery Se Video Chuno' : 'Video Badlo'),
          ),
          if (_videoPath != null) ...[
            const SizedBox(height: 8),
            Text('Selected: ${_videoPath!.split('/').last}',
                style: const TextStyle(color: AppColors.cyan)),
          ],
          const SizedBox(height: 16),
          const Text('Trim (Seconds mein — khali chhodo poori video ke liye):',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Start (sec)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'End (sec)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Aspect Ratio:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Original', '9:16', '1:1', '16:9'].map((r) {
              return ChoiceChip(
                label: Text(r),
                selected: _ratio == r,
                selectedColor: AppColors.purple,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: const TextStyle(color: Colors.white),
                onSelected: (_) => setState(() => _ratio = r),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Speed Control:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [0.5, 1.0, 1.25, 1.5, 2.0].map((sp) {
              return ChoiceChip(
                label: Text('${sp}x'),
                selected: _speed == sp,
                selectedColor: AppColors.cyan,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: const TextStyle(color: Colors.white),
                onSelected: (_) => setState(() => _speed = sp),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Color Grading & Effects:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: effectsList.map((fx) {
              return ChoiceChip(
                label: Text(fx),
                selected: _effect == fx,
                selectedColor: AppColors.pink,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: const TextStyle(color: Colors.white),
                onSelected: (_) => setState(() => _effect = fx),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Mute Original Audio'),
            value: _mute,
            activeColor: AppColors.purple,
            onChanged: (v) => setState(() => _mute = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_videoPath == null || _processing) ? null : _export,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.movie_creation),
            label: Text(_processing ? 'Exporting Video...' : 'Export Now'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 6: MULTI-CLIP MERGER
// ============================================================================
class MultiMergeScreen extends StatefulWidget {
  const MultiMergeScreen({super.key});

  @override
  State<MultiMergeScreen> createState() => _MultiMergeScreenState();
}

class _MultiMergeScreenState extends State<MultiMergeScreen> {
  final List<String> _paths = [];
  bool _processing = false;
  String _status = '';

  Future<void> _pickVideos() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.video, allowMultiple: true);
    if (res != null) {
      setState(() {
        for (final f in res.files) {
          if (f.path != null) _paths.add(f.path!);
        }
      });
    }
  }

  Future<void> _merge() async {
    if (_paths.length < 2) return;
    setState(() {
      _processing = true;
      _status = 'Clips normalize ho rahi hain...';
    });

    final tempDir = await getTemporaryDirectory();
    final normFiles = <File>[];
    final listFile = File(
        '${tempDir.path}/merge_${DateTime.now().millisecondsSinceEpoch}.txt');

    try {
      final listBuf = StringBuffer();
      for (int i = 0; i < _paths.length; i++) {
        if (mounted) {
          setState(
              () => _status = 'Processing clip ${i + 1} / ${_paths.length}...');
        }
        final normPath =
            '${tempDir.path}/norm_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        final normCmd =
            '-y -i "${_paths[i]}" -vf "scale=720:1280:force_original_aspect_ratio=decrease,'
            'pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1" -r 30 '
            '-c:v mpeg4 -q:v 4 -c:a aac -ar 44100 -ac 2 "$normPath"';
        final s = await FFmpegKit.execute(normCmd);
        if (!ReturnCode.isSuccess(await s.getReturnCode())) {
          throw Exception('Clip ${i + 1} process fail hua.');
        }
        normFiles.add(File(normPath));
        listBuf.writeln("file '$normPath'");
      }

      await listFile.writeAsString(listBuf.toString());
      if (mounted) setState(() => _status = 'Final video merge ho raha hai...');

      final out = await StudioStorage.newOutputPath('merged');
      final mergeCmd =
          '-y -f concat -safe 0 -i "${listFile.path}" -c copy "$out"';
      final session = await FFmpegKit.execute(mergeCmd);
      final rc = await session.getReturnCode();

      if (!mounted) return;
      if (ReturnCode.isSuccess(rc)) {
        final dl = await StudioStorage.mirrorToDownloads(out);
        if (!mounted) return;
        _showExportSuccessDialog(context, out, dl);
      } else {
        throw Exception('Final merge fail hua.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      for (final f in normFiles) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      try {
        if (await listFile.exists()) await listFile.delete();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _processing = false;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Clip Merger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _pickVideos,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Videos'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed:
                    _processing ? null : () => setState(() => _paths.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_paths.isEmpty)
            const Text('Kam se kam 2 videos add karo merge karne ke liye.',
                style: TextStyle(color: AppColors.textMuted))
          else
            ..._paths.asMap().entries.map((entry) => ListTile(
                  tileColor: AppColors.surface,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.purple,
                    child: Text('${entry.key + 1}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(entry.value.split('/').last,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.red),
                    onPressed: _processing
                        ? null
                        : () => setState(() => _paths.removeAt(entry.key)),
                  ),
                )),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.cyan)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: (_paths.length < 2 || _processing) ? null : _merge,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.merge_type),
            label: Text(
                _processing ? 'Merging...' : 'Merge ${_paths.length} Clips'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 7: PHOTO-TO-VIDEO REELS
// ============================================================================
class PhotoReelsScreen extends StatefulWidget {
  const PhotoReelsScreen({super.key});

  @override
  State<PhotoReelsScreen> createState() => _PhotoReelsScreenState();
}

class _PhotoReelsScreenState extends State<PhotoReelsScreen> {
  final List<String> _images = [];
  double _secPerPhoto = 2.0;
  bool _processing = false;

  Future<void> _pickPhotos() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) {
      setState(() {
        for (final f in res.files) {
          if (f.path != null && _images.length < 15) _images.add(f.path!);
        }
      });
    }
  }

  Future<void> _buildReel() async {
    if (_images.isEmpty) return;
    setState(() => _processing = true);

    final tempDir = await getTemporaryDirectory();
    final parts = <File>[];
    final listFile = File(
        '${tempDir.path}/photos_${DateTime.now().millisecondsSinceEpoch}.txt');

    try {
      final buf = StringBuffer();
      for (int i = 0; i < _images.length; i++) {
        final p =
            '${tempDir.path}/pclip_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        final cmd = '-y -loop 1 -t $_secPerPhoto -i "${_images[i]}" '
            '-vf "scale=720:1280:force_original_aspect_ratio=decrease,'
            'pad=720:1280:(ow-iw)/2:(oh-ih)/2,format=yuv420p" '
            '-r 25 -c:v mpeg4 -q:v 3 "$p"';
        final s = await FFmpegKit.execute(cmd);
        if (!ReturnCode.isSuccess(await s.getReturnCode())) {
          throw Exception('Photo ${i + 1} render fail.');
        }
        parts.add(File(p));
        buf.writeln("file '$p'");
      }

      await listFile.writeAsString(buf.toString());
      final out = await StudioStorage.newOutputPath('photo_reel');
      final session = await FFmpegKit.execute(
          '-y -f concat -safe 0 -i "${listFile.path}" -c copy "$out"');

      if (!mounted) return;
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        final dl = await StudioStorage.mirrorToDownloads(out);
        if (!mounted) return;
        _showExportSuccessDialog(context, out, dl);
      } else {
        throw Exception('Photo Reel concat fail.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      for (final f in parts) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      try {
        if (await listFile.exists()) await listFile.delete();
      } catch (_) {}
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo-to-Video Reels')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text('Add Photos (${_images.length}/15)'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed:
                    _processing ? null : () => setState(() => _images.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Har Photo Kitne Second Dikhe:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1.5, 2.0, 3.0, 4.0].map((s) {
              return ChoiceChip(
                label: Text('${s}s'),
                selected: _secPerPhoto == s,
                selectedColor: AppColors.green,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: const TextStyle(color: Colors.white),
                onSelected: (_) => setState(() => _secPerPhoto = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_images.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_images[i]),
                    width: 75,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: (_images.isEmpty || _processing) ? null : _buildReel,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.movie),
            label: Text(_processing ? 'Building Reel...' : 'Create 9:16 Reel'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 2: PROJECTS TAB (SAVED EXPORTS — FIXED BUTTON!)
// ============================================================================
class ProjectsTab extends StatefulWidget {
  final VoidCallback onCreateNew;
  const ProjectsTab({super.key, required this.onCreateNew});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await StudioStorage.listExports();
    if (mounted) {
      setState(() {
        _files = list;
        _loading = false;
      });
    }
  }

  Future<void> _deleteFile(File f) async {
    try {
      await f.delete();
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved Exports',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 34),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.purple.withAlpha(60)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_outlined,
                                  size: 52, color: AppColors.textMuted),
                              const SizedBox(height: 14),
                              const Text(
                                'Abhi koi exported project nahi hai',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: widget.onCreateNew,
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Colors.white),
                                label: const Text(
                                  'Naya Video Edit Karo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _files.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final file = _files[i];
                          final name = file.path.split('/').last;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.surfaceLight),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.purple.withAlpha(40),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.play_arrow,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        StudioStorage.formatFileSize(file),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.play_circle,
                                      color: AppColors.cyan),
                                  onPressed: () =>
                                      _openVideoPreview(context, file.path),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share,
                                      color: AppColors.green),
                                  onPressed: () =>
                                      Share.shareXFiles([XFile(file.path)]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.red),
                                  onPressed: () => _deleteFile(file),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 3: PACKS TAB (DIRECT EFFECT PRESETS)
// ============================================================================
class PacksTab extends StatelessWidget {
  final ValueChanged<String> onSelectEffect;
  const PacksTab({super.key, required this.onSelectEffect});

  @override
  Widget build(BuildContext context) {
    final presets = [
      ('Vice Neon', 'GTA / Gaming high-neon contrast', AppColors.pink),
      ('Miami Sunset', 'Warm golden viral Reels look', Colors.orangeAccent),
      ('Cyber Cyan', 'Futuristic cold blue/cyan glow', AppColors.cyan),
      ('Cinematic', 'Smooth movie color grading', AppColors.purple),
      ('HDR Pop', 'Sharp punchy Shorts clarity', AppColors.green),
      ('Noir B&W', 'Dramatic motivational monochrome', Colors.grey),
      ('Vintage', 'Retro film aesthetic', Colors.amber),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: presets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = presets[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.$3.withAlpha(80)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: p.$3.withAlpha(45),
                child: Icon(Icons.auto_awesome, color: p.$3),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.$1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(p.$2,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => onSelectEffect(p.$1),
                child: const Text('Use'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// TAB 4: ME TAB (TEST BUILD STATUS)
// ============================================================================
class MeTab extends StatelessWidget {
  final VoidCallback onOpenProjects;
  const MeTab({super.key, required this.onOpenProjects});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.purple, AppColors.pink],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viral Clip Studio v2.3',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Direct APK Test Build • 100% Features Unlocked (No Payment Lock)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          tileColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.folder, color: AppColors.cyan),
          title: const Text('Export Folder'),
          subtitle: const Text('Downloads/ViralClipStudio + App Projects'),
          onTap: onOpenProjects,
        ),
        const SizedBox(height: 10),
        ListTile(
          tileColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.cleaning_services, color: Colors.amber),
          title: const Text('Clear Temporary Cache'),
          subtitle: const Text('YouTube raw temp files saaf karo'),
          onTap: () async {
            await StudioStorage.clearTempCache();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Temp cache saaf ho gaya!')),
              );
            }
          },
        ),
      ],
    );
  }
}

// ============================================================================
// SHARED SUCCESS DIALOG & IN-APP VIDEO PREVIEW PLAYER
// ============================================================================
void _showExportSuccessDialog(
    BuildContext context, String appPath, String? downloadsPath) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.green),
          SizedBox(width: 8),
          Text('Export Ready!', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Text(
        downloadsPath != null
            ? 'Video Projects tab aur Downloads/ViralClipStudio dono mein save ho gaya hai!'
            : 'Video Projects tab mein save ho gaya hai!',
        style: const TextStyle(color: AppColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Share.shareXFiles([XFile(appPath)]);
          },
          child: const Text('Share'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            _openVideoPreview(context, appPath);
          },
          child: const Text('Play Video'),
        ),
      ],
    ),
  );
}

void _openVideoPreview(BuildContext context, String path) {
  showDialog(
    context: context,
    builder: (_) => _VideoPreviewDialog(path: path),
  );
}

class _VideoPreviewDialog extends StatefulWidget {
  final String path;
  const _VideoPreviewDialog({required this.path});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _ctrl.play();
          _ctrl.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_ready)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: AspectRatio(
                  aspectRatio: _ctrl.value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                ),
              )
            else
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                    });
                  },
                ),
                ElevatedButton.icon(
                  onPressed: () => Share.shareXFiles([XFile(widget.path)]),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Band Karo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
