import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ViralClipStudioApp());
}

class AppColors {
  static const bg = Color(0xFF0A0B14);
  static const surface = Color(0xFF141625);
  static const surfaceLight = Color(0xFF1E2136);
  static const neonPurple = Color(0xFF9B2BFF);
  static const neonPink = Color(0xFFE02BFF);
  static const neonBlue = Color(0xFF00B4FF);
  static const neonCyan = Color(0xFF00F0FF);
}

class ViralClipStudioApp extends StatelessWidget {
  const ViralClipStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viral Clip Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        cardColor: AppColors.surface,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonPurple,
          secondary: AppColors.neonCyan,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// 1. SPLASH SCREEN (Neon Branding - Viral Clip Studio)
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 0.04;
      });
      if (_progress >= 1.0) {
        timer.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShellScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.1,
            colors: [
              Color(0xFF28124D),
              Color(0xFF100E24),
              AppColors.bg,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.neonCyan, AppColors.neonPurple, AppColors.neonPink],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPurple.withValues(alpha: 0.55),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 70, color: Colors.white),
                ),
                const SizedBox(height: 28),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    children: [
                      TextSpan(text: 'Viral Clip ', style: TextStyle(color: Colors.white)),
                      TextSpan(
                        text: 'Studio',
                        style: TextStyle(
                          color: AppColors.neonPink,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create  •  Edit  •  Share',
                  style: TextStyle(color: Colors.white70, fontSize: 15, letterSpacing: 1.2),
                ),
                const SizedBox(height: 24),
                const Text(
                  '"Your Shorts & Reels Studio\nin Your Pocket"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonPink),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Loading Studio...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. MAIN SHELL (Bottom Nav: Home / Projects / AI Tools / Me)
// ============================================================================
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;
  List<String> _recentExports = [];

  @override
  void initState() {
    super.initState();
    _loadRecentExports();
  }

  Future<void> _loadRecentExports() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_exports') ?? [];
    if (!mounted) return;
    setState(() => _recentExports = list);
  }

  Future<void> _saveExportRecord(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_exports') ?? [];
    list.remove(path);
    list.insert(0, path);
    if (list.length > 20) list.removeLast();
    await prefs.setStringList('recent_exports', list);
    if (!mounted) return;
    setState(() => _recentExports = list);
  }

  Future<void> _openNewProject({int initialTool = 0}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    final exportedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => VideoStudioEditorScreen(
          videoPath: result.files.single.path!,
          videoName: result.files.single.name,
          initialToolTab: initialTool,
        ),
      ),
    );

    if (exportedPath != null) {
      await _saveExportRecord(exportedPath);
    }
  }

  void _openAutoSplit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AutoSplitScreen(onExported: _saveExportRecord),
      ),
    );
  }

  void _openMerger() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiClipMergerScreen(onExported: _saveExportRecord),
      ),
    );
  }

  void _showSoonDialog(String title, String desc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.neonCyan),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(desc, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Hero Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C1D95), Color(0xFF9333EA), Color(0xFF1D4ED8)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonPurple.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.movie_filter_rounded, size: 40, color: AppColors.neonCyan),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Smarter\nwith Studio ✨',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.15),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _openAutoSplit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                      child: const Text('Try Auto-Split →', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2 Big Action Cards (New Project + Auto-Split)
        Row(
          children: [
            Expanded(
              child: _bigActionCard(
                title: 'New Project\n(+)',
                icon: Icons.add_box_rounded,
                colors: const [Color(0xFFD946EF), Color(0xFF7E22CE)],
                onTap: () => _openNewProject(initialTool: 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigActionCard(
                title: 'Auto-Split\nShorts ✨',
                icon: Icons.content_cut_rounded,
                colors: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                onTap: _openAutoSplit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2x3 Quick Tools Grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _quickToolCard(
              label: 'Merge Clips',
              icon: Icons.merge_type_rounded,
              color: const Color(0xFFEC4899),
              onTap: _openMerger,
            ),
            _quickToolCard(
              label: 'Speed',
              icon: Icons.speed_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => _openNewProject(initialTool: 2),
            ),
            _quickToolCard(
              label: 'Crop 9:16',
              icon: Icons.crop_rounded,
              color: const Color(0xFF38BDF8),
              onTap: () => _openNewProject(initialTool: 1),
            ),
            _quickToolCard(
              label: 'Rotate / Flip',
              icon: Icons.flip_rounded,
              color: const Color(0xFFA855F7),
              onTap: () => _openNewProject(initialTool: 3),
            ),
            _quickToolCard(
              label: 'Mute Audio',
              icon: Icons.volume_off_rounded,
              color: const Color(0xFF60A5FA),
              onTap: () => _openNewProject(initialTool: 4),
            ),
            _quickToolCard(
              label: 'Effects',
              icon: Icons.auto_fix_high_rounded,
              color: const Color(0xFFFBBF24),
              onTap: () => _showSoonDialog(
                'Effects & Filters (Phase 2)',
                'Glow, Shake, Blur, VHS, Glitch aur Photo-to-Video transitions agle engine update (Phase 2) mein unlock honge!',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Quick Recent Activity Strip
        if (_recentExports.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Exports',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => setState(() => _tabIndex = 1),
                child: const Text('See all', style: TextStyle(color: AppColors.neonCyan)),
              ),
            ],
          ),
          _exportHistoryTile(_recentExports.first),
        ],
      ],
    );
  }

  Widget _bigActionCard({
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 122,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickToolCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportHistoryTile(String path) {
    final fileName = path.split('/').last;
    final exists = File(path).existsSync();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.neonPurple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.video_file_rounded, color: AppColors.neonCyan),
        ),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          exists ? 'Saved in Gallery -> Viral Clip Studio' : 'Saved in Phone Gallery',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        trailing: exists
            ? IconButton(
                icon: const Icon(Icons.share_rounded, color: AppColors.neonCyan),
                onPressed: () => Share.shareXFiles([XFile(path)], text: 'Edited with Viral Clip Studio'),
              )
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildProjectsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Saved Exports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (_recentExports.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('recent_exports');
                  if (mounted) setState(() => _recentExports = []);
                },
                child: const Text('Clear List', style: TextStyle(color: Colors.redAccent)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentExports.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const Icon(Icons.folder_open_rounded, size: 54, color: Colors.white24),
                const SizedBox(height: 12),
                const Text('Abhi koi exported project nahi hai', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _openNewProject(),
                  icon: const Icon(Icons.add),
                  label: const Text('Start New Project'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonPurple),
                ),
              ],
            ),
          )
        else
          ..._recentExports.map(_exportHistoryTile),
      ],
    );
  }

  Widget _buildAiToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('AI & Effects Lab', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Phase 1 ke saare offline editing tools Home tab mein 100% Free active hain. Ye upcoming Phase 2 & 3 modules hain:',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            _aiCard('Auto Captions\n(Hindi / English)', Icons.closed_caption_rounded, AppColors.neonBlue, 'Phase 3'),
            _aiCard('Photo-to-Video\nTransitions', Icons.auto_awesome_motion, AppColors.neonPink, 'Phase 2'),
            _aiCard('Remove\nBackground', Icons.person_remove_rounded, AppColors.neonPurple, 'Phase 3'),
            _aiCard('AI Video\nGenerator', Icons.movie_creation_rounded, AppColors.neonCyan, 'Phase 3'),
            _aiCard('Glow / Glitch\nFilters', Icons.flare_rounded, Colors.amber, 'Phase 2'),
            _aiCard('Background\nMusic Studio', Icons.music_note_rounded, Colors.greenAccent, 'Phase 2'),
          ],
        ),
      ],
    );
  }

  Widget _aiCard(String title, IconData icon, Color color, String badge) {
    return InkWell(
      onTap: () => _showSoonDialog(
        title.replaceAll('\n', ' '),
        'Ye feature $badge roadmap mein planned hai. Pehle Phase 1 ke saare offline video tools test kar lete hain!',
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildMeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 28),
                  SizedBox(width: 10),
                  Text('Viral Clip Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Status: FREE TEST BUILD (v1.0)\nSabhi Phase 1 tools testing ke liye 100% unlocked hain. Testing pass hone ke baad Pro Paywall enable kiya jayega.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Phase 1 Tools:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 10),
              Text('✓ Real Video Player Preview & Timeline Trim'),
              Text('✓ Auto-Split (15s / 30s / 45s / 60s Parts)'),
              Text('✓ Aspect Ratio Crop (9:16, 1:1, 16:9)'),
              Text('✓ Speed Control (0.5x Slow-Mo se 2.0x Fast)'),
              Text('✓ Rotate (90°/180°/270°) & Mirror Flip'),
              Text('✓ Multi-Clip Video Merger & Audio Mute'),
              Text('✓ 480P / 720P / 1080P / Original Export'),
              Text('✓ Direct Gallery Save & Social Share'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeTab(),
      _buildProjectsTab(),
      _buildAiToolsTab(),
      _buildMeTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            children: [
              TextSpan(text: 'Viral Clip ', style: TextStyle(color: Colors.white)),
              TextSpan(
                text: 'Studio',
                style: TextStyle(color: AppColors.neonPink, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_rounded, size: 14, color: Colors.greenAccent),
                SizedBox(width: 4),
                Text(
                  'FREE TEST',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.neonPurple.withValues(alpha: 0.28),
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_rounded), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'AI Tools'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. VIDEO STUDIO EDITOR SCREEN (Real Preview + Timeline + Tools)
// ============================================================================
class VideoStudioEditorScreen extends StatefulWidget {
  final String videoPath;
  final String videoName;
  final int initialToolTab;

  const VideoStudioEditorScreen({
    super.key,
    required this.videoPath,
    required this.videoName,
    this.initialToolTab = 0,
  });

  @override
  State<VideoStudioEditorScreen> createState() => _VideoStudioEditorScreenState();
}

class _VideoStudioEditorScreenState extends State<VideoStudioEditorScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  double _totalSeconds = 1.0;
  RangeValues _trimRange = const RangeValues(0, 1);

  int _activeTool = 0; // 0: Trim, 1: Crop, 2: Speed, 3: Rotate/Flip, 4: Audio
  String _selectedRatio = 'Original'; // Original, 9:16, 1:1, 16:9
  double _selectedSpeed = 1.0;
  int _rotationDeg = 0;
  String _flipMode = 'None';
  bool _muteAudio = false;
  String _quickResolution = '1080P';

  @override
  void initState() {
    super.initState();
    _activeTool = widget.initialToolTab;
    _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.file(File(widget.videoPath));
    await ctrl.initialize();
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    final secs = ctrl.value.duration.inMilliseconds / 1000.0;
    final safeTotal = secs > 1.0 ? secs : 1.0;
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    setState(() {
      _controller = ctrl;
      _isInitialized = true;
      _totalSeconds = safeTotal;
      _trimRange = RangeValues(0, safeTotal);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatTime(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _resetAll() {
    setState(() {
      _trimRange = RangeValues(0, _totalSeconds);
      _selectedRatio = 'Original';
      _selectedSpeed = 1.0;
      _rotationDeg = 0;
      _flipMode = 'None';
      _muteAudio = false;
    });
    _controller?.setPlaybackSpeed(1.0);
    _controller?.setVolume(1.0);
  }

  Future<void> _goToExportScreen() async {
    await _controller?.pause();
    if (!mounted) return;

    final exportedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ExportConfigScreen(
          videoPath: widget.videoPath,
          videoName: widget.videoName,
          totalSeconds: _totalSeconds,
          startSec: _trimRange.start,
          endSec: _trimRange.end,
          aspectRatio: _selectedRatio,
          speed: _selectedSpeed,
          rotationDeg: _rotationDeg,
          flipMode: _flipMode,
          muteAudio: _muteAudio,
          initialResolution: _quickResolution,
        ),
      ),
    );

    if (exportedPath != null && mounted) {
      Navigator.of(context).pop(exportedPath);
    }
  }

  Widget _buildToolControls() {
    switch (_activeTool) {
      case 0: // Trim
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Start: ${_formatTime(_trimRange.start)}', style: const TextStyle(color: AppColors.neonCyan)),
                Text(
                  'Clip: ${_formatTime(_trimRange.end - _trimRange.start)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('End: ${_formatTime(_trimRange.end)}', style: const TextStyle(color: AppColors.neonPink)),
              ],
            ),
            RangeSlider(
              values: _trimRange,
              min: 0,
              max: _totalSeconds,
              activeColor: AppColors.neonPurple,
              inactiveColor: Colors.white24,
              onChanged: (values) {
                if (values.end - values.start < 1.0) return;
                setState(() => _trimRange = values);
                _controller?.seekTo(Duration(milliseconds: (values.start * 1000).round()));
              },
            ),
          ],
        );

      case 1: // Crop
        return Wrap(
          spacing: 10,
          children: ['Original', '9:16', '1:1', '16:9'].map((r) {
            return ChoiceChip(
              label: Text(r == '9:16' ? '9:16 Shorts' : r),
              selected: _selectedRatio == r,
              selectedColor: AppColors.neonPurple,
              onSelected: (_) => setState(() => _selectedRatio = r),
            );
          }).toList(),
        );

      case 2: // Speed
        return Wrap(
          spacing: 8,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
            return ChoiceChip(
              label: Text('${s}x'),
              selected: _selectedSpeed == s,
              selectedColor: AppColors.neonPurple,
              onSelected: (_) {
                setState(() => _selectedSpeed = s);
                _controller?.setPlaybackSpeed(s);
              },
            );
          }).toList(),
        );

      case 3: // Rotate & Flip
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [0, 90, 180, 270].map((deg) {
                return ChoiceChip(
                  label: Text(deg == 0 ? '0°' : '$deg°'),
                  selected: _rotationDeg == deg,
                  selectedColor: AppColors.neonPurple,
                  onSelected: (_) => setState(() => _rotationDeg = deg),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['None', 'Horizontal', 'Vertical'].map((m) {
                return ChoiceChip(
                  label: Text('Flip: $m'),
                  selected: _flipMode == m,
                  selectedColor: AppColors.neonBlue,
                  onSelected: (_) => setState(() => _flipMode = m),
                );
              }).toList(),
            ),
          ],
        );

      case 4: // Audio
      default:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mute / Remove Original Audio'),
          subtitle: const Text('Exported video se original awaaz hata dega'),
          value: _muteAudio,
          activeThumbColor: AppColors.neonCyan,
          onChanged: (v) {
            setState(() => _muteAudio = v);
            _controller?.setVolume(v ? 0.0 : 1.0);
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posSec = (_controller?.value.position.inMilliseconds ?? 0) / 1000.0;
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoName, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _quickResolution,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              items: ['480P', '720P', '1080P', 'Original']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _quickResolution = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: ElevatedButton(
              onPressed: _isInitialized ? _goToExportScreen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Export', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video Preview Viewport
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: _isInitialized && _controller != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),

          // Playback & Active Edits Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatTime(posSec)} / ${_formatTime(_totalSeconds)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Reset all edits',
                      onPressed: _resetAll,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    ),
                    IconButton(
                      onPressed: _controller == null
                          ? null
                          : () => isPlaying ? _controller!.pause() : _controller!.play(),
                      icon: Icon(
                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: AppColors.neonCyan,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Visual Multi-Track Timeline Strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.neonPurple, AppColors.neonBlue]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'VIDEO  •  Crop: $_selectedRatio  •  Speed: ${_selectedSpeed}x',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _muteAudio
                        ? Colors.redAccent.withValues(alpha: 0.3)
                        : AppColors.neonCyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _muteAudio
                        ? 'AUDIO  •  Muted'
                        : 'AUDIO  •  Original  •  Rotate: $_rotationDeg°  •  Flip: $_flipMode',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Active Tool Panel
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _buildToolControls(),
          ),
          const SizedBox(height: 10),

          // Bottom Editor Tool Tabs
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _editorTabBtn(0, Icons.content_cut_rounded, 'Trim'),
                _editorTabBtn(1, Icons.crop_rounded, 'Crop'),
                _editorTabBtn(2, Icons.speed_rounded, 'Speed'),
                _editorTabBtn(3, Icons.rotate_90_degrees_cw_rounded, 'Rotate'),
                _editorTabBtn(4, Icons.audiotrack_rounded, 'Audio'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorTabBtn(int index, IconData icon, String label) {
    final active = _activeTool == index;
    return InkWell(
      onTap: () => setState(() => _activeTool = index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.neonCyan : Colors.white60, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? AppColors.neonCyan : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. EXPORT VIDEO SCREEN & SUCCESS SCREEN
// ============================================================================
class ExportConfigScreen extends StatefulWidget {
  final String videoPath;
  final String videoName;
  final double totalSeconds;
  final double startSec;
  final double endSec;
  final String aspectRatio;
  final double speed;
  final int rotationDeg;
  final String flipMode;
  final bool muteAudio;
  final String initialResolution;

  const ExportConfigScreen({
    super.key,
    required this.videoPath,
    required this.videoName,
    required this.totalSeconds,
    required this.startSec,
    required this.endSec,
    required this.aspectRatio,
    required this.speed,
    required this.rotationDeg,
    required this.flipMode,
    required this.muteAudio,
    required this.initialResolution,
  });

  @override
  State<ExportConfigScreen> createState() => _ExportConfigScreenState();
}

class _ExportConfigScreenState extends State<ExportConfigScreen> {
  late String _resolution;
  bool _saveToGallery = true;
  bool _isExporting = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _resolution = widget.initialResolution;
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _statusText = 'Rendering video... Please wait';
    });

    try {
      if (_saveToGallery) {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          await Gal.requestAccess(toAlbum: true);
        }
      }

      var editor = VideoEditorBuilder(videoPath: widget.videoPath);
      bool hasOperation = false;

      final startMs = (widget.startSec * 1000).round();
      final endMs = (widget.endSec * 1000).round();
      final totalMs = (widget.totalSeconds * 1000).round();

      if (startMs > 200 || (totalMs - endMs) > 500) {
        editor = editor.trim(startTimeMs: startMs, endTimeMs: endMs);
        hasOperation = true;
      }

      if (widget.aspectRatio == '9:16') {
        editor = editor.crop(aspectRatio: VideoAspectRatio.ratio9x16);
        hasOperation = true;
      } else if (widget.aspectRatio == '1:1') {
        editor = editor.crop(aspectRatio: VideoAspectRatio.ratio1x1);
        hasOperation = true;
      } else if (widget.aspectRatio == '16:9') {
        editor = editor.crop(aspectRatio: VideoAspectRatio.ratio16x9);
        hasOperation = true;
      }

      if (widget.speed != 1.0) {
        editor = editor.speed(speed: widget.speed);
        hasOperation = true;
      }

      if (widget.rotationDeg == 90) {
        editor = editor.rotate(degree: RotationDegree.degree90);
        hasOperation = true;
      } else if (widget.rotationDeg == 180) {
        editor = editor.rotate(degree: RotationDegree.degree180);
        hasOperation = true;
      } else if (widget.rotationDeg == 270) {
        editor = editor.rotate(degree: RotationDegree.degree270);
        hasOperation = true;
      }

      if (widget.flipMode == 'Horizontal') {
        editor = editor.flip(flipDirection: FlipDirection.horizontal);
        hasOperation = true;
      } else if (widget.flipMode == 'Vertical') {
        editor = editor.flip(flipDirection: FlipDirection.vertical);
        hasOperation = true;
      }

      if (widget.muteAudio) {
        editor = editor.removeAudio();
        hasOperation = true;
      }

      if (_resolution == '480P') {
        editor = editor.compress(resolution: VideoResolution.p480);
        hasOperation = true;
      } else if (_resolution == '720P') {
        editor = editor.compress(resolution: VideoResolution.p720);
        hasOperation = true;
      } else if (_resolution == '1080P') {
        editor = editor.compress(resolution: VideoResolution.p1080);
        hasOperation = true;
      }

      if (!hasOperation) {
        editor = editor.trim(startTimeMs: 0, endTimeMs: totalMs);
      }

      final outputPath = await editor.export();

      if (outputPath == null) {
        throw Exception('Export returned empty file');
      }

      if (_saveToGallery) {
        await Gal.putVideo(outputPath, album: 'Viral Clip Studio');
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExportSuccessScreen(
            outputPath: outputPath,
            savedToGallery: _saveToGallery,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _statusText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Video')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.videoName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Range: ${widget.startSec.toStringAsFixed(1)}s - ${widget.endSec.toStringAsFixed(1)}s\n'
                  'Crop: ${widget.aspectRatio}  •  Speed: ${widget.speed}x\n'
                  'Rotate: ${widget.rotationDeg}°  •  Flip: ${widget.flipMode}  •  Mute: ${widget.muteAudio ? "Yes" : "No"}',
                  style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Select Resolution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _resCard('480P', 'Fast'),
              const SizedBox(width: 8),
              _resCard('720P', 'HD'),
              const SizedBox(width: 8),
              _resCard('1080P', 'Full HD'),
              const SizedBox(width: 8),
              _resCard('Original', 'Max/4K'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save to Gallery'),
              subtitle: const Text('Album: Viral Clip Studio'),
              value: _saveToGallery,
              activeThumbColor: AppColors.neonPurple,
              onChanged: _isExporting ? null : (v) => setState(() => _saveToGallery = v),
            ),
          ),
          const SizedBox(height: 28),
          if (_isExporting) ...[
            const LinearProgressIndicator(color: AppColors.neonPink, backgroundColor: Colors.white12),
            const SizedBox(height: 12),
            Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neonCyan)),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _startExport,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: Text(
              _isExporting ? 'Exporting...' : 'Export Now',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resCard(String title, String sub) {
    final selected = _resolution == title;
    return Expanded(
      child: InkWell(
        onTap: _isExporting ? null : () => setState(() => _resolution = title),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.neonPurple.withValues(alpha: 0.22) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.neonPink : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class ExportSuccessScreen extends StatelessWidget {
  final String outputPath;
  final bool savedToGallery;

  const ExportSuccessScreen({
    super.key,
    required this.outputPath,
    required this.savedToGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.greenAccent, width: 3),
                ),
                child: const Icon(Icons.check_rounded, size: 58, color: Colors.greenAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'Video Exported\nSuccessfully!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                savedToGallery
                    ? 'Gallery -> Viral Clip Studio album mein save ho gaya hai.'
                    : 'Video successfully render ho gaya hai.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Share.shareXFiles(
                          [XFile(outputPath)],
                          text: 'Edited with Viral Clip Studio',
                        );
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(outputPath),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. AUTO-SPLIT SHORTS SCREEN (Free Test Mode)
// ============================================================================
class AutoSplitScreen extends StatefulWidget {
  final Future<void> Function(String path) onExported;

  const AutoSplitScreen({super.key, required this.onExported});

  @override
  State<AutoSplitScreen> createState() => _AutoSplitScreenState();
}

class _AutoSplitScreenState extends State<AutoSplitScreen> {
  String? _videoPath;
  String _videoName = 'Koi video select nahi hai';
  int _chunkSec = 30;
  bool _crop9x16 = true;
  bool _isProcessing = false;
  String _status = '';

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res != null && res.files.single.path != null) {
      setState(() {
        _videoPath = res.files.single.path;
        _videoName = res.files.single.name;
      });
    }
  }

  Future<void> _runSplit() async {
    if (_videoPath == null) return;
    setState(() {
      _isProcessing = true;
      _status = 'Video duration read ho raha hai...';
    });

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      final ctrl = VideoPlayerController.file(File(_videoPath!));
      await ctrl.initialize();
      final totalMs = ctrl.value.duration.inMilliseconds;
      await ctrl.dispose();

      if (totalMs <= 0) throw Exception('Video duration read nahi ho paya');

      final chunkMs = _chunkSec * 1000;
      final segments = <List<int>>[];
      int start = 0;
      while (start < totalMs) {
        int end = start + chunkMs;
        if (end > totalMs) end = totalMs;
        if ((end - start) < 2000 && segments.isNotEmpty) break;
        segments.add([start, end]);
        start = end;
      }

      int saved = 0;
      String? lastPath;
      for (int i = 0; i < segments.length; i++) {
        if (!mounted) return;
        setState(() => _status = 'Part ${i + 1} / ${segments.length} export ho raha hai...');

        var editor = VideoEditorBuilder(videoPath: _videoPath!)
            .trim(startTimeMs: segments[i][0], endTimeMs: segments[i][1]);
        if (_crop9x16) {
          editor = editor.crop(aspectRatio: VideoAspectRatio.ratio9x16);
        }
        final outPath = await editor.export();
        if (outPath != null) {
          await Gal.putVideo(outPath, album: 'Viral Clip Studio');
          await widget.onExported(outPath);
          lastPath = outPath;
          saved++;
        }
      }

      if (!mounted) return;
      if (saved > 0 && lastPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$saved parts Gallery -> Viral Clip Studio mein save ho gaye!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Split Shorts')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Long Video -> Multiple Shorts Parts',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_videoName, style: const TextStyle(color: AppColors.neonCyan, fontSize: 13)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_rounded),
                  label: const Text('Select Long Video'),
                ),
                const SizedBox(height: 18),
                const Text('Har Part ki Length:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [15, 30, 45, 60].map((sec) {
                    return ChoiceChip(
                      label: Text('${sec}s'),
                      selected: _chunkSec == sec,
                      selectedColor: AppColors.neonPurple,
                      onSelected: (_) => setState(() => _chunkSec = sec),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('9:16 Vertical Shorts Crop'),
                  value: _crop9x16,
                  activeThumbColor: AppColors.neonCyan,
                  onChanged: _isProcessing ? null : (v) => setState(() => _crop9x16 = v),
                ),
                const SizedBox(height: 14),
                if (_isProcessing) ...[
                  const LinearProgressIndicator(color: AppColors.neonCyan),
                  const SizedBox(height: 8),
                  Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neonCyan)),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: (_isProcessing || _videoPath == null) ? null : _runSplit,
                  icon: const Icon(Icons.content_cut_rounded),
                  label: const Text('Auto-Split & Save All Parts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. MULTI-CLIP MERGER SCREEN
// ============================================================================
class MultiClipMergerScreen extends StatefulWidget {
  final Future<void> Function(String path) onExported;

  const MultiClipMergerScreen({super.key, required this.onExported});

  @override
  State<MultiClipMergerScreen> createState() => _MultiClipMergerScreenState();
}

class _MultiClipMergerScreenState extends State<MultiClipMergerScreen> {
  List<String> _paths = [];
  List<String> _names = [];
  bool _isProcessing = false;

  Future<void> _pickVideos() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (res == null) return;
    final paths = <String>[];
    final names = <String>[];
    for (final f in res.files) {
      if (f.path != null) {
        paths.add(f.path!);
        names.add(f.name);
      }
    }
    if (paths.isNotEmpty) {
      setState(() {
        _paths = paths;
        _names = names;
      });
    }
  }

  Future<void> _merge() async {
    if (_paths.length < 2) return;
    setState(() => _isProcessing = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      final outPath = await VideoEditorBuilder(videoPath: _paths.first)
          .merge(otherVideoPaths: _paths.sublist(1))
          .export();

      if (outPath == null) throw Exception('Merge failed');
      await Gal.putVideo(outPath, album: 'Viral Clip Studio');
      await widget.onExported(outPath);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExportSuccessScreen(outputPath: outPath, savedToGallery: true),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Clip Merger')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('2+ Videos Jod Kar Ek Banayein', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_names.isNotEmpty)
                  ..._names.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${e.key + 1}. ${e.value}',
                            style: const TextStyle(color: AppColors.neonCyan, fontSize: 13),
                          ),
                        ),
                      ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickVideos,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(_paths.isEmpty ? 'Select 2 or More Videos' : '${_paths.length} Videos Selected'),
                ),
                const SizedBox(height: 16),
                if (_isProcessing) ...[
                  const LinearProgressIndicator(color: AppColors.neonPink),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: (_isProcessing || _paths.length < 2) ? null : _merge,
                  icon: const Icon(Icons.merge_type_rounded),
                  label: Text(_isProcessing ? 'Merging...' : 'Merge & Save to Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
