import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
  static const amber = Color(0xFFF59E0B);
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
// VIRAL GRAPH DATA MODELS & ENGINE (YT MOST REPLAYED + OFFLINE AUDIO HYPE)
// ============================================================================
class ViralGraphPoint {
  final double timeSec;
  final double score; // 0.0 to 1.0

  const ViralGraphPoint({required this.timeSec, required this.score});
}

class ViralClipCandidate {
  final int rank;
  final double peakSec;
  final double startSec;
  final double endSec;
  final int viralScorePct; // 0 - 100
  bool selected;

  ViralClipCandidate({
    required this.rank,
    required this.peakSec,
    required this.startSec,
    required this.endSec,
    required this.viralScorePct,
    this.selected = true,
  });
}

class ViralGraphEngine {
  /// Fetches YouTube's official "Most Replayed" heatmap graph from the watch page.
  static Future<List<ViralGraphPoint>> fetchYoutubeHeatmap(
      String videoId) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
      final req = await client.getUrl(uri);
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      );
      req.headers.set('Accept-Language', 'en-US,en;q=0.9');

      final resp = await req.close();
      if (resp.statusCode != 200) return [];
      final html = await resp.transform(utf8.decoder).join();

      final mapBySec = <int, double>{};

      // Pattern 1: startMillis / timeRangeStartMillis followed by intensity score
      final reg1 = RegExp(
        r'"(?:timeRangeStartMillis|startMillis)"\s*:\s*"?(\d+)"?[^{}]{0,240}?'
        r'"(?:heatMarkerIntensityScoreNormalized|intensityScoreNormalized)"\s*:\s*([0-9.eE+-]+)',
      );
      for (final m in reg1.allMatches(html)) {
        final ms = int.tryParse(m.group(1) ?? '');
        final sc = double.tryParse(m.group(2) ?? '');
        if (ms != null && sc != null) {
          final secKey = (ms / 1000.0).round();
          final prev = mapBySec[secKey] ?? 0.0;
          if (sc > prev) mapBySec[secKey] = sc;
        }
      }

      // Pattern 2: reverse key order fallback
      if (mapBySec.length < 5) {
        final reg2 = RegExp(
          r'"(?:heatMarkerIntensityScoreNormalized|intensityScoreNormalized)"\s*:\s*([0-9.eE+-]+)'
          r'[^{}]{0,240}?"(?:timeRangeStartMillis|startMillis)"\s*:\s*"?(\d+)"?',
        );
        for (final m in reg2.allMatches(html)) {
          final sc = double.tryParse(m.group(1) ?? '');
          final ms = int.tryParse(m.group(2) ?? '');
          if (ms != null && sc != null) {
            final secKey = (ms / 1000.0).round();
            final prev = mapBySec[secKey] ?? 0.0;
            if (sc > prev) mapBySec[secKey] = sc;
          }
        }
      }

      if (mapBySec.length < 5) return [];

      double maxScore = 0.0;
      for (final v in mapBySec.values) {
        if (v > maxScore) maxScore = v;
      }
      if (maxScore <= 0) return [];

      final sortedKeys = mapBySec.keys.toList()..sort();
      return sortedKeys.map((sec) {
        final normalized = (mapBySec[sec]! / maxScore).clamp(0.0, 1.0);
        return ViralGraphPoint(timeSec: sec.toDouble(), score: normalized);
      }).toList();
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  /// Offline Audio Hype / Shout Graph scanner using FFmpeg RMS energy levels.
  static Future<List<ViralGraphPoint>> scanAudioHypeGraph(
      String inputPathOrUrl) async {
    final tempDir = await getTemporaryDirectory();
    final logFile = File(
        '${tempDir.path}/hype_${DateTime.now().millisecondsSinceEpoch}.txt');
    try {
      // Downsample audio to 8kHz mono, compute RMS volume every 2 seconds
      final cmd = '-y -i "$inputPathOrUrl" -vn -ar 8000 -ac 1 '
          '-af "asetnsamples=16000,astats=metadata=1:reset=1,'
          'ametadata=print:key=lavfi.astats.Overall.RMS_level:file=\'${logFile.path}\'" '
          '-f null -';
      await FFmpegKit.execute(cmd);

      if (!await logFile.exists()) return [];
      final content = await logFile.readAsString();
      if (content.trim().isEmpty) return [];

      final lines = content.split('\n');
      final rawPoints = <(double, double)>[];
      double? pendingTime;

      final timeReg = RegExp(r'pts_time:([0-9.]+)');
      final rmsReg = RegExp(r'RMS_level=([-0-9.]+)');

      for (final line in lines) {
        final tm = timeReg.firstMatch(line);
        if (tm != null) {
          pendingTime = double.tryParse(tm.group(1) ?? '');
          continue;
        }
        final rm = rmsReg.firstMatch(line);
        if (rm != null && pendingTime != null) {
          final db = double.tryParse(rm.group(1) ?? '');
          if (db != null && db.isFinite) {
            rawPoints.add((pendingTime, db.clamp(-60.0, 0.0)));
          }
          pendingTime = null;
        }
      }

      if (rawPoints.length < 4) return [];

      double minDb = 0.0;
      double maxDb = -60.0;
      for (final p in rawPoints) {
        if (p.$2 < minDb) minDb = p.$2;
        if (p.$2 > maxDb) maxDb = p.$2;
      }
      final span = (maxDb - minDb).abs();
      if (span < 0.5) return [];

      return rawPoints.map((p) {
        final norm = ((p.$2 - minDb) / span).clamp(0.0, 1.0);
        return ViralGraphPoint(timeSec: p.$1, score: norm);
      }).toList();
    } catch (_) {
      return [];
    } finally {
      try {
        if (await logFile.exists()) await logFile.delete();
      } catch (_) {}
    }
  }

  /// Finds ranked, non-overlapping viral clips from a graph with intro-skip & build-up.
  static List<ViralClipCandidate> detectViralClips({
    required List<ViralGraphPoint> points,
    required double totalSeconds,
    required double clipDurationSec,
    double minScoreThreshold = 0.52,
    int maxClips = 25,
  }) {
    if (points.isEmpty || totalSeconds <= 2) return [];

    final safeClipLen = clipDurationSec.clamp(5.0, totalSeconds);
    final introSkipSec = totalSeconds > 45 ? 10.0 : 0.0;
    final buildupSec = safeClipLen >= 30 ? 7.0 : 4.0;

    // 1. Find local peaks above threshold
    final localPeaks = <ViralGraphPoint>[];
    for (int i = 0; i < points.length; i++) {
      final curr = points[i];
      if (curr.timeSec < introSkipSec) continue;
      if (curr.score < minScoreThreshold) continue;

      final prevScore = i > 0 ? points[i - 1].score : 0.0;
      final nextScore = i < points.length - 1 ? points[i + 1].score : 0.0;
      if (curr.score >= prevScore && curr.score >= nextScore) {
        localPeaks.add(curr);
      }
    }

    // Fallback if curve is very smooth and strict local maxima returned few items
    if (localPeaks.isEmpty) {
      for (final p in points) {
        if (p.timeSec >= introSkipSec && p.score >= 0.35) {
          localPeaks.add(p);
        }
      }
    }

    // 2. Sort strongest viral peaks first
    localPeaks.sort((a, b) => b.score.compareTo(a.score));

    // 3. No-Overlap greedy selection
    final picked = <ViralClipCandidate>[];
    final minGap = math.max(safeClipLen * 0.72, 12.0);

    for (final peak in localPeaks) {
      if (picked.length >= maxClips) break;

      final tooClose = picked.any((c) => (c.peakSec - peak.timeSec).abs() < minGap);
      if (tooClose) continue;

      double start = (peak.timeSec - buildupSec).clamp(0.0, totalSeconds);
      double end = start + safeClipLen;
      if (end > totalSeconds) {
        end = totalSeconds;
        start = (end - safeClipLen).clamp(0.0, end);
      }

      // Check window overlap with already accepted clips
      final overlapsWindow = picked.any((c) {
        final overlapStart = math.max(c.startSec, start);
        final overlapEnd = math.min(c.endSec, end);
        return (overlapEnd - overlapStart) > (safeClipLen * 0.35);
      });
      if (overlapsWindow) continue;

      final pct = (peak.score * 100).round().clamp(50, 99);
      picked.add(ViralClipCandidate(
        rank: picked.length + 1,
        peakSec: peak.timeSec,
        startSec: start,
        endSec: end,
        viralScorePct: pct,
        selected: picked.length < 3, // Top 3 pre-selected by default
      ));
    }

    return picked;
  }
}

// ============================================================================
// INTERACTIVE VIRAL GRAPH WIDGET (TAP TO SEEK + HIGHLIGHTED PEAKS)
// ============================================================================
class ViralGraphWidget extends StatelessWidget {
  final List<ViralGraphPoint> points;
  final List<ViralClipCandidate> clips;
  final double totalSeconds;
  final double currentSec;
  final ValueChanged<double> onSeek;

  const ViralGraphWidget({
    super.key,
    required this.points,
    required this.clips,
    required this.totalSeconds,
    required this.currentSec,
    required this.onSeek,
  });

  void _handleTouch(double dx, double width) {
    if (width <= 0 || totalSeconds <= 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    onSeek(ratio * totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple.withAlpha(80)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _handleTouch(d.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _handleTouch(d.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              painter: _ViralGraphPainter(
                points: points,
                clips: clips,
                totalSeconds: totalSeconds,
                currentSec: currentSec,
              ),
              size: Size(constraints.maxWidth, 86),
            ),
          );
        },
      ),
    );
  }
}

class _ViralGraphPainter extends CustomPainter {
  final List<ViralGraphPoint> points;
  final List<ViralClipCandidate> clips;
  final double totalSeconds;
  final double currentSec;

  _ViralGraphPainter({
    required this.points,
    required this.clips,
    required this.totalSeconds,
    required this.currentSec,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || totalSeconds <= 0) return;

    final w = size.width;
    final h = size.height;
    const padTop = 10.0;
    const padBot = 6.0;
    final drawH = h - padTop - padBot;

    // Subtle threshold guide line
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(22)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, padTop + drawH * 0.45),
      Offset(w, padTop + drawH * 0.45),
      gridPaint,
    );

    // Highlight selected viral clip windows
    for (final clip in clips) {
      if (!clip.selected) continue;
      final x1 = (clip.startSec / totalSeconds).clamp(0.0, 1.0) * w;
      final x2 = (clip.endSec / totalSeconds).clamp(0.0, 1.0) * w;
      final bandPaint = Paint()..color = AppColors.pink.withAlpha(42);
      canvas.drawRect(Rect.fromLTRB(x1, 0, x2, h), bandPaint);
    }

    // Build viral wave path
    final linePath = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.timeSec / totalSeconds).clamp(0.0, 1.0) * w;
      final y = padTop + (1.0 - p.score.clamp(0.0, 1.0)) * drawH;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    final lastX = (points.last.timeSec / totalSeconds).clamp(0.0, 1.0) * w;
    fillPath.lineTo(lastX, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.pink.withAlpha(130),
          AppColors.purple.withAlpha(25),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = AppColors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(linePath, strokePaint);

    // Draw glowing dots for detected viral peaks
    for (final clip in clips) {
      final px = (clip.peakSec / totalSeconds).clamp(0.0, 1.0) * w;
      final py =
          padTop + (1.0 - (clip.viralScorePct / 100.0).clamp(0.0, 1.0)) * drawH;
      final dotColor = clip.selected ? AppColors.green : AppColors.amber;
      canvas.drawCircle(
        Offset(px, py),
        clip.selected ? 4.5 : 3.2,
        Paint()..color = dotColor,
      );
    }

    // Playhead line
    final playX = (currentSec / totalSeconds).clamp(0.0, 1.0) * w;
    canvas.drawLine(
      Offset(playX, 0),
      Offset(playX, h),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _ViralGraphPainter oldDelegate) => true;
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

  // Exact Streamer Split FFmpeg filter_complex (Top Facecam + Bottom Gameplay)
  static String buildStreamerSplitFilter({
    required double camX,
    required double camY,
    required double camW,
    required double camH,
    required int topHeight,
  }) {
    final cw = camW.clamp(0.10, 0.90);
    final ch = camH.clamp(0.10, 0.90);
    final cx = camX.clamp(0.0, (0.99 - cw).clamp(0.0, 0.89));
    final cy = camY.clamp(0.0, (0.99 - ch).clamp(0.0, 0.89));

    final safeTop = (topHeight ~/ 2) * 2;
    final safeBottom = 1280 - safeTop;

    final camCrop =
        'crop=iw*${cw.toStringAsFixed(3)}:ih*${ch.toStringAsFixed(3)}:iw*${cx.toStringAsFixed(3)}:ih*${cy.toStringAsFixed(3)}';

    return '[0:v]$camCrop,scale=720:$safeTop:force_original_aspect_ratio=increase,crop=720:$safeTop,setsar=1[cam];'
        '[0:v]scale=720:$safeBottom:force_original_aspect_ratio=increase,crop=720:$safeBottom,setsar=1[game];'
        '[cam][game]vstack=inputs=2[v]';
  }
}

// ============================================================================
// REUSABLE INTERACTIVE FACECAM BOX OVERLAY (DRAG TO ALIGN OVER FACECAM)
// ============================================================================
class VideoWithFacecamSelector extends StatelessWidget {
  final VideoPlayerController? controller;
  final String? fallbackThumbnailUrl;
  final bool showFacecamBox;
  final double camX;
  final double camY;
  final double camW;
  final double camH;
  final void Function(double newX, double newY) onDragBox;

  const VideoWithFacecamSelector({
    super.key,
    required this.controller,
    this.fallbackThumbnailUrl,
    required this.showFacecamBox,
    required this.camX,
    required this.camY,
    required this.camW,
    required this.camH,
    required this.onDragBox,
  });

  @override
  Widget build(BuildContext context) {
    final isVideoReady = controller != null && controller!.value.isInitialized;
    final aspect = isVideoReady && controller!.value.aspectRatio > 0.2
        ? controller!.value.aspectRatio
        : (16 / 9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: aspect,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final boxW = (camW * w).clamp(28.0, w);
              final boxH = (camH * h).clamp(28.0, h);
              final left = (camX * w).clamp(0.0, (w - boxW).clamp(0.0, w));
              final top = (camY * h).clamp(0.0, (h - boxH).clamp(0.0, h));

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideoReady)
                    VideoPlayer(controller!)
                  else if (fallbackThumbnailUrl != null)
                    Image.network(
                      fallbackThumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.ondemand_video,
                            size: 48, color: AppColors.textMuted),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.movie,
                          size: 48, color: AppColors.textMuted),
                    ),
                  if (showFacecamBox)
                    Positioned(
                      left: left,
                      top: top,
                      width: boxW,
                      height: boxH,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          final nextX = (camX + details.delta.dx / w)
                              .clamp(0.0, (1.0 - camW).clamp(0.0, 0.90));
                          final nextY = (camY + details.delta.dy / h)
                              .clamp(0.0, (1.0 - camH).clamp(0.0, 0.90));
                          onDragBox(nextX, nextY);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.green.withAlpha(45),
                            border: Border.all(
                              color: AppColors.green,
                              width: 2.5,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              color: AppColors.green,
                              child: const Text(
                                'FACECAM',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
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
    final goProjects = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (goProjects == true) {
      _openProjects();
    } else {
      setState(() => _projectsRefreshKey++);
    }
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
                  'TEST v2.4',
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
                    Icons.auto_graph,
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
                          'NEW v2.4 • VIRAL GRAPH + LIVE PLAYER',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'YouTube Viral Clipper',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Graph scan karo -> Viral clips chuno -> Facecam Split mein export karo',
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
          'Studio Tools (100% Free Test)',
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
              icon: Icons.splitscreen,
              color: AppColors.pink,
              title: 'Streamer Split',
              subtitle: 'Gallery + Audio Hype + Cam',
              onTap: onOpenStreamerSplit,
            ),
            _toolCard(
              icon: Icons.content_cut,
              color: AppColors.cyan,
              title: 'Auto-Split Shorts',
              subtitle: '30s / 60s parts auto cut',
              onTap: onOpenAutoSplit,
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
              title: 'YT Viral Graph',
              subtitle: 'Auto Hooks + Queue Export',
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
// TOOL 1: YOUTUBE VIRAL GRAPH CLIPPER (LIVE PLAYER + HEATMAP + QUEUE SPLIT)
// ============================================================================
class YoutubeClipperScreen extends StatefulWidget {
  const YoutubeClipperScreen({super.key});

  @override
  State<YoutubeClipperScreen> createState() => _YoutubeClipperScreenState();
}

class _YoutubeClipperScreenState extends State<YoutubeClipperScreen> {
  final TextEditingController _urlCtrl = TextEditingController();

  bool _loadingInfo = false;
  bool _loadingPlayer = false;
  bool _playerFailed = false;
  bool _scanningAudio = false;
  bool _processing = false;
  bool _cancelRequested = false;

  String _statusText = '';
  double _exportProgress = 0;

  Video? _video;
  StreamInfo? _selectedStream;
  VideoPlayerController? _ytPlayer;
  double _currentPlaySec = 0;
  double _totalSeconds = 60;

  // Viral Graph state
  List<ViralGraphPoint> _graphPoints = [];
  List<ViralClipCandidate> _viralClips = [];
  String _graphSource = ''; // 'youtube', 'audio', or ''
  double _targetClipSec = 30.0; // 30s or 60s
  bool _manualMode = false;
  RangeValues _manualRange = const RangeValues(0, 30);

  // Output format & Facecam Box (Photo 2 style default)
  String _aspectMode = 'streamer_split';
  double _camX = 0.74;
  double _camY = 0.14;
  double _camW = 0.24;
  double _camH = 0.28;
  int _topSplitHeight = 538; // 42% Facecam top + 58% Gameplay bottom

  @override
  void dispose() {
    _disposePlayer();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _disposePlayer() {
    _ytPlayer?.removeListener(_onPlayerTick);
    _ytPlayer?.dispose();
    _ytPlayer = null;
  }

  void _onPlayerTick() {
    if (!mounted || _ytPlayer == null || !_ytPlayer!.value.isInitialized) return;
    final pos = _ytPlayer!.value.position.inMilliseconds / 1000.0;
    if ((pos - _currentPlaySec).abs() >= 0.4) {
      setState(() => _currentPlaySec = pos.clamp(0.0, _totalSeconds));
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() => _urlCtrl.text = data.text!.trim());
    }
  }

  Future<void> _loadAndScanYoutube() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) {
      _showSnack('Pehle YouTube link paste karo bhai');
      return;
    }

    FocusScope.of(context).unfocus();
    _disposePlayer();

    setState(() {
      _loadingInfo = true;
      _loadingPlayer = false;
      _playerFailed = false;
      _video = null;
      _selectedStream = null;
      _graphPoints = [];
      _viralClips = [];
      _graphSource = '';
      _manualMode = false;
      _currentPlaySec = 0;
      _statusText = 'Video aur Viral Graph scan ho raha hai...';
    });

    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(rawUrl);
      final manifestFuture = yt.videos.streamsClient.getManifest(video.id);
      final heatmapFuture =
          ViralGraphEngine.fetchYoutubeHeatmap(video.id.value);

      final manifest = await manifestFuture;
      final heatmap = await heatmapFuture;

      StreamInfo? stream;
      if (manifest.muxed.isNotEmpty) {
        stream = manifest.muxed.withHighestBitrate();
      } else if (manifest.videoOnly.isNotEmpty) {
        stream = manifest.videoOnly.withHighestBitrate();
      }

      if (stream == null) {
        throw Exception('Koi playable stream nahi mila.');
      }

      final secs = (video.duration?.inSeconds ?? 60).toDouble();
      final safeTotal = secs < 2 ? 2.0 : secs;
      final defaultEnd = safeTotal > 30 ? 30.0 : safeTotal;

      final clips = heatmap.isNotEmpty
          ? ViralGraphEngine.detectViralClips(
              points: heatmap,
              totalSeconds: safeTotal,
              clipDurationSec: _targetClipSec,
            )
          : <ViralClipCandidate>[];

      if (!mounted) return;
      setState(() {
        _video = video;
        _selectedStream = stream;
        _totalSeconds = safeTotal;
        _manualRange = RangeValues(0, defaultEnd);
        _graphPoints = heatmap;
        _viralClips = clips;
        _graphSource = heatmap.isNotEmpty ? 'youtube' : '';
        _manualMode = clips.isEmpty;
        _loadingInfo = false;
        _loadingPlayer = true;
        _statusText = '';
      });

      await _initLivePlayer(stream.url);
    } catch (e) {
      if (mounted) {
        _showSnack('Video load fail: ${e.toString()}');
        setState(() {
          _loadingInfo = false;
          _loadingPlayer = false;
          _statusText = '';
        });
      }
    } finally {
      yt.close();
    }
  }

  Future<void> _initLivePlayer(Uri streamUrl) async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        streamUrl,
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        },
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      ctrl.addListener(_onPlayerTick);
      await ctrl.play();

      final durSec = ctrl.value.duration.inSeconds.toDouble();
      setState(() {
        _ytPlayer = ctrl;
        _loadingPlayer = false;
        _playerFailed = false;
        if (durSec > 2) {
          _totalSeconds = durSec;
          if (_manualRange.end > _totalSeconds) {
            _manualRange = RangeValues(0, _totalSeconds.clamp(2.0, 30.0));
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPlayer = false;
          _playerFailed = true;
        });
      }
    }
  }

  Future<void> _runAudioHypeFallback() async {
    if (_selectedStream == null || _scanningAudio) return;
    setState(() {
      _scanningAudio = true;
      _statusText = 'Audio Hype / Shout Graph scan ho raha hai...';
    });

    try {
      final pts =
          await ViralGraphEngine.scanAudioHypeGraph(_selectedStream!.url.toString());
      if (!mounted) return;
      if (pts.isEmpty) {
        _showSnack('Audio scan nahi ho paya — Manual Custom mode use karo.');
      } else {
        final clips = ViralGraphEngine.detectViralClips(
          points: pts,
          totalSeconds: _totalSeconds,
          clipDurationSec: _targetClipSec,
        );
        setState(() {
          _graphPoints = pts;
          _viralClips = clips;
          _graphSource = 'audio';
          _manualMode = clips.isEmpty;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanningAudio = false;
          _statusText = '';
        });
      }
    }
  }

  void _rebuildClipsForDuration(double newSec) {
    setState(() {
      _targetClipSec = newSec;
      _manualMode = false;
      if (_graphPoints.isNotEmpty) {
        _viralClips = ViralGraphEngine.detectViralClips(
          points: _graphPoints,
          totalSeconds: _totalSeconds,
          clipDurationSec: _targetClipSec,
        );
      }
    });
  }

  void _selectTopN(int n) {
    setState(() {
      for (int i = 0; i < _viralClips.length; i++) {
        _viralClips[i].selected = i < n;
      }
    });
  }

  void _seekTo(double sec, {bool autoPlay = false}) {
    final target = sec.clamp(0.0, _totalSeconds);
    setState(() => _currentPlaySec = target);
    if (_ytPlayer != null && _ytPlayer!.value.isInitialized) {
      _ytPlayer!.seekTo(Duration(milliseconds: (target * 1000).round()));
      if (autoPlay && !_ytPlayer!.value.isPlaying) {
        _ytPlayer!.play();
      }
    }
  }

  void _setStartFromPlayer() {
    final maxStart = (_totalSeconds - 1.0).clamp(0.0, _totalSeconds);
    final s = _currentPlaySec.clamp(0.0, maxStart);
    double e = _manualRange.end;
    if (e <= s + 1) {
      e = (s + 30).clamp(s + 1, _totalSeconds);
    }
    setState(() {
      _manualRange = RangeValues(s, e);
      _manualMode = true;
    });
    _showSnack('Start set: ${StudioStorage.formatSeconds(s)}');
  }

  void _setEndFromPlayer() {
    final e = _currentPlaySec.clamp(1.0, _totalSeconds);
    double s = _manualRange.start;
    if (s >= e - 1) {
      s = (e - 30).clamp(0.0, e - 1);
    }
    setState(() {
      _manualRange = RangeValues(s, e);
      _manualMode = true;
    });
    _showSnack('End set: ${StudioStorage.formatSeconds(e)}');
  }

  void _applyCornerPreset(String corner) {
    setState(() {
      switch (corner) {
        case 'top_right':
          _camX = (1.0 - _camW - 0.01).clamp(0.0, 0.85);
          _camY = 0.02;
          break;
        case 'mid_right':
          _camX = (1.0 - _camW - 0.01).clamp(0.0, 0.85);
          _camY = 0.14;
          break;
        case 'top_left':
          _camX = 0.01;
          _camY = 0.02;
          break;
        case 'bottom_left':
          _camX = 0.01;
          _camY = (1.0 - _camH - 0.02).clamp(0.0, 0.85);
          break;
        case 'bottom_right':
          _camX = (1.0 - _camW - 0.01).clamp(0.0, 0.85);
          _camY = (1.0 - _camH - 0.02).clamp(0.0, 0.85);
          break;
      }
    });
  }

  String _buildClipFfmpegCmd(
      String inputPathOrUrl, String outputPath, double startSec, double durSec) {
    final s = startSec.toStringAsFixed(1);
    final d = durSec.clamp(1.0, _totalSeconds).toStringAsFixed(1);

    if (_aspectMode == 'streamer_split') {
      final fc = StudioStorage.buildStreamerSplitFilter(
        camX: _camX,
        camY: _camY,
        camW: _camW,
        camH: _camH,
        topHeight: _topSplitHeight,
      );
      return '-y -ss $s -i "$inputPathOrUrl" -t $d '
          '-filter_complex "$fc" -map "[v]" -map 0:a? '
          '-c:v mpeg4 -q:v 3 -c:a aac "$outputPath"';
    } else if (_aspectMode == '9:16_crop') {
      return '-y -ss $s -i "$inputPathOrUrl" -t $d '
          '-vf "crop=ih*9/16:ih,scale=720:1280" '
          '-c:v mpeg4 -q:v 3 -c:a aac "$outputPath"';
    } else if (_aspectMode == '9:16_blur') {
      return '-y -ss $s -i "$inputPathOrUrl" -t $d '
          '-filter_complex "[0:v]scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,boxblur=20:5[bg];'
          '[0:v]scale=720:1280:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2" '
          '-c:v mpeg4 -q:v 3 -c:a aac "$outputPath"';
    } else {
      return '-y -ss $s -i "$inputPathOrUrl" -t $d -c copy "$outputPath"';
    }
  }

  Future<void> _cancelQueue() async {
    _cancelRequested = true;
    await FFmpegKit.cancel();
    if (mounted) {
      setState(() => _statusText = 'Export roka ja raha hai...');
    }
  }

  Future<void> _exportQueue() async {
    if (_video == null || _selectedStream == null) return;

    // Build jobs list: either selected Viral Graph clips or 1 Manual Custom clip
    final jobs = <(String label, double start, double end)>[];
    if (_manualMode) {
      jobs.add(('custom', _manualRange.start, _manualRange.end));
    } else {
      for (final c in _viralClips.where((e) => e.selected)) {
        jobs.add(('viral_r${c.rank}', c.startSec, c.endSec));
      }
    }

    if (jobs.isEmpty) {
      _showSnack('Kam se kam 1 viral clip select karo bhai');
      return;
    }

    _ytPlayer?.pause();
    _cancelRequested = false;
    setState(() {
      _processing = true;
      _exportProgress = 0;
      _statusText = 'Queue start ho rahi hai (${jobs.length} clips)...';
    });

    final yt = YoutubeExplode();
    File? downloadedRaw;
    final exportedPaths = <String>[];
    String? lastDownloadCopy;

    try {
      String activeSource = _selectedStream!.url.toString();
      bool usingLocalFile = false;

      for (int i = 0; i < jobs.length; i++) {
        if (_cancelRequested) break;
        final job = jobs[i];
        final dur = (job.$3 - job.$2).clamp(1.0, _totalSeconds);
        final outPath = await StudioStorage.newOutputPath('yt_${job.$1}');

        if (mounted) {
          setState(() {
            _exportProgress = i / jobs.length;
            _statusText =
                'Exporting Clip ${i + 1} / ${jobs.length} (${StudioStorage.formatSeconds(job.$2)} - ${StudioStorage.formatSeconds(job.$3)})...';
          });
        }

        // Try FFmpeg on activeSource (first attempt uses fast direct URL)
        final cmd = _buildClipFfmpegCmd(activeSource, outPath, job.$2, dur);
        final session = await FFmpegKit.execute(cmd);
        final rc = await session.getReturnCode();
        final outFile = File(outPath);
        bool ok = ReturnCode.isSuccess(rc) &&
            await outFile.exists() &&
            await outFile.length() > 10000;

        // If direct stream failed and we haven't downloaded locally yet, download ONCE and reuse!
        if (!ok && !usingLocalFile && !_cancelRequested) {
          if (mounted) {
            setState(() => _statusText =
                'Direct clip blocked—video ek baar download ho raha hai (sab clips ke liye)...');
          }
          final tempDir = await getTemporaryDirectory();
          downloadedRaw = File(
              '${tempDir.path}/yt_raw_${DateTime.now().millisecondsSinceEpoch}.mp4');

          final stream = yt.videos.streamsClient.get(_selectedStream!);
          final totalBytes = _selectedStream!.size.totalBytes;
          int received = 0;
          final sink = downloadedRaw.openWrite();

          await for (final chunk in stream) {
            if (_cancelRequested) break;
            sink.add(chunk);
            received += chunk.length;
            if (totalBytes > 0 && mounted) {
              final pct = ((received / totalBytes) * 100).clamp(0, 100).round();
              setState(() {
                _exportProgress = (received / totalBytes).clamp(0.0, 1.0);
                _statusText = 'Downloading source video once... $pct%';
              });
            }
          }
          await sink.flush();
          await sink.close();

          if (_cancelRequested) break;

          activeSource = downloadedRaw.path;
          usingLocalFile = true;

          if (mounted) {
            setState(() => _statusText =
                'Rendering Clip ${i + 1} / ${jobs.length} (Streamer Split)...');
          }
          final localCmd =
              _buildClipFfmpegCmd(activeSource, outPath, job.$2, dur);
          final localSession = await FFmpegKit.execute(localCmd);
          final localRc = await localSession.getReturnCode();
          ok = ReturnCode.isSuccess(localRc) && await outFile.exists();
        }

        if (ok) {
          exportedPaths.add(outPath);
          lastDownloadCopy = await StudioStorage.mirrorToDownloads(outPath);
        }
      }

      if (!mounted) return;
      if (exportedPaths.isEmpty) {
        _showSnack(_cancelRequested
            ? 'Export cancel kar diya gaya.'
            : 'Export fail hua — dobara try karo.');
      } else if (exportedPaths.length == 1) {
        _showExportSuccessDialog(context, exportedPaths.first, lastDownloadCopy);
      } else {
        _showMultiExportSuccessDialog(context, exportedPaths.length);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}');
    } finally {
      yt.close();
      try {
        if (downloadedRaw != null && await downloadedRaw.exists()) {
          await downloadedRaw.delete();
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _processing = false;
          _cancelRequested = false;
          _statusText = '';
          _exportProgress = 0;
        });
      }
    }
  }

  void _showMultiExportSuccessDialog(BuildContext context, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.green),
            SizedBox(width: 8),
            Text('Viral Clips Ready!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          '$count Viral Clips Projects tab aur Downloads/ViralClipStudio mein save ho gayi hain!',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Yahin Raho'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true); // Opens Projects tab
            },
            child: const Text('Projects Dekho'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isPlayerReady = _ytPlayer != null && _ytPlayer!.value.isInitialized;
    final showBox = _aspectMode == 'streamer_split';
    final selectedCount = _viralClips.where((c) => c.selected).length;

    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Viral Clipper')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'YouTube Video ya Stream ka link daalo:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_loadingInfo || _processing) ? null : _loadAndScanYoutube,
              icon: _loadingInfo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_graph),
              label: Text(_loadingInfo
                  ? 'Video & Viral Graph Scan Ho Raha Hai...'
                  : 'Load Video & Scan Viral Graph'),
            ),
          ),
          if (_video != null) ...[
            const SizedBox(height: 16),

            // LIVE VIDEO PLAYER + DRAGGABLE FACECAM BOX
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.purple.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoWithFacecamSelector(
                        controller: _ytPlayer,
                        fallbackThumbnailUrl: _video!.thumbnails.highResUrl,
                        showFacecamBox: showBox,
                        camX: _camX,
                        camY: _camY,
                        camW: _camW,
                        camH: _camH,
                        onDragBox: (nx, ny) => setState(() {
                          _camX = nx;
                          _camY = ny;
                        }),
                      ),
                      if (_loadingPlayer)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(170),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.pink),
                              SizedBox(height: 8),
                              Text('Live Video Buffer Ho Raha Hai...',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isPlayerReady) ...[
                    Row(
                      children: [
                        Text(
                          StudioStorage.formatSeconds(_currentPlaySec),
                          style: const TextStyle(
                              color: AppColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                        Expanded(
                          child: Slider(
                            value: _currentPlaySec.clamp(0.0, _totalSeconds),
                            min: 0,
                            max: _totalSeconds,
                            activeColor: AppColors.pink,
                            inactiveColor: AppColors.surfaceLight,
                            onChanged: (v) => _seekTo(v),
                          ),
                        ),
                        Text(
                          StudioStorage.formatSeconds(_totalSeconds),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.replay_10, color: Colors.white),
                          onPressed: () => _seekTo(_currentPlaySec - 10),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceLight,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          onPressed: () {
                            setState(() {
                              _ytPlayer!.value.isPlaying
                                  ? _ytPlayer!.pause()
                                  : _ytPlayer!.play();
                            });
                          },
                          icon: Icon(
                            _ytPlayer!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          label: Text(
                              _ytPlayer!.value.isPlaying ? 'Pause' : 'Play'),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.forward_10, color: Colors.white),
                          onPressed: () => _seekTo(_currentPlaySec + 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setStartFromPlayer,
                            icon: const Icon(Icons.first_page, size: 16),
                            label: Text(
                              'Set Start (${StudioStorage.formatSeconds(_currentPlaySec)})',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setEndFromPlayer,
                            icon: const Icon(Icons.last_page, size: 16),
                            label: Text(
                              'Set End (${StudioStorage.formatSeconds(_currentPlaySec)})',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_playerFailed) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Live stream preview slow hai—Retry dabao ya neeche graph se clips export karo.',
                            style:
                                TextStyle(color: AppColors.amber, fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loadingPlayer = true;
                              _playerFailed = false;
                            });
                            _initLivePlayer(_selectedStream!.url);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _video!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // VIRAL GRAPH SECTION
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.pink.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_fire_department,
                              color: AppColors.pink, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Viral Retention Graph',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (_graphSource.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_graphSource == 'youtube'
                                    ? AppColors.green
                                    : AppColors.cyan)
                                .withAlpha(35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _graphSource == 'youtube'
                                ? 'YT Most Replayed'
                                : 'Audio Hype',
                            style: TextStyle(
                              color: _graphSource == 'youtube'
                                  ? AppColors.green
                                  : AppColors.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_graphPoints.isNotEmpty) ...[
                    ViralGraphWidget(
                      points: _graphPoints,
                      clips: _viralClips,
                      totalSeconds: _totalSeconds,
                      currentSec: _currentPlaySec,
                      onSeek: (sec) => _seekTo(sec, autoPlay: true),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withAlpha(45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _viralClips.isEmpty
                            ? 'Graph flat hai — Manual Custom se clip cut karo.'
                            : 'Is video mein ${_viralClips.length} Viral Clips nikal sakte hain! (Graph par tap karke seek karo)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Is video par YouTube ka "Most Replayed" graph abhi available nahi hai (naya ya kam views video).',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cyan,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: (_scanningAudio || _processing)
                                  ? null
                                  : _runAudioHypeFallback,
                              icon: _scanningAudio
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Icon(Icons.graphic_eq),
                              label: Text(_scanningAudio
                                  ? 'Audio Hype Scan Ho Raha Hai...'
                                  : 'Scan Audio Hype Graph (Backup)'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Clip Mode Toggle: 30s Viral / 60s Viral / Manual Custom
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _choiceChip('30s Viral Clips',
                          !_manualMode && _targetClipSec == 30.0, () {
                        _rebuildClipsForDuration(30.0);
                      }),
                      _choiceChip('60s Viral Clips',
                          !_manualMode && _targetClipSec == 60.0, () {
                        _rebuildClipsForDuration(60.0);
                      }),
                      _choiceChip('Manual Custom', _manualMode, () {
                        setState(() => _manualMode = true);
                      }),
                    ],
                  ),

                  // DETECTED VIRAL CLIPS LIST WITH TOP 5 / TOP 10 / ALL
                  if (!_manualMode && _viralClips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_viralClips.length >= 3)
                          _miniBtn('Top 3', () => _selectTopN(3)),
                        if (_viralClips.length >= 5)
                          _miniBtn('Top 5', () => _selectTopN(5)),
                        if (_viralClips.length >= 10)
                          _miniBtn('Top 10', () => _selectTopN(10)),
                        _miniBtn('All (${_viralClips.length})',
                            () => _selectTopN(_viralClips.length)),
                        _miniBtn('Clear', () => _selectTopN(0)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _viralClips.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final clip = _viralClips[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: clip.selected
                                  ? AppColors.purple.withAlpha(45)
                                  : AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: clip.selected
                                    ? AppColors.pink
                                    : AppColors.surfaceLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: clip.selected,
                                  activeColor: AppColors.pink,
                                  onChanged: (v) => setState(
                                      () => clip.selected = v ?? false),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Clip #${clip.rank}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  AppColors.green.withAlpha(40),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${clip.viralScorePct}% Viral',
                                              style: const TextStyle(
                                                color: AppColors.green,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${StudioStorage.formatSeconds(clip.startSec)} - ${StudioStorage.formatSeconds(clip.endSec)} '
                                        '(Peak: ${StudioStorage.formatSeconds(clip.peakSec)})',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Preview this moment',
                                  icon: const Icon(Icons.play_circle_fill,
                                      color: AppColors.cyan, size: 28),
                                  onPressed: () =>
                                      _seekTo(clip.startSec, autoPlay: true),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // MANUAL RANGE SLIDER
                  if (_manualMode) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Start: ${StudioStorage.formatSeconds(_manualRange.start)}',
                          style: const TextStyle(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                        Text(
                          'Clip: ${(_manualRange.end - _manualRange.start).round()}s',
                          style: const TextStyle(
                              color: AppColors.pink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                        Text(
                          'End: ${StudioStorage.formatSeconds(_manualRange.end)}',
                          style: const TextStyle(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _manualRange,
                      min: 0,
                      max: _totalSeconds,
                      activeColor: AppColors.pink,
                      inactiveColor: AppColors.surfaceLight,
                      onChanged: (v) {
                        if (v.end - v.start >= 1.0) {
                          setState(() => _manualRange = v);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // OUTPUT FORMAT & FACECAM BOX CONTROLS
            const Text(
              'Output Format & Facecam Layout',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choiceChip(
                  'Streamer Split (9:16)',
                  _aspectMode == 'streamer_split',
                  () => setState(() => _aspectMode = 'streamer_split'),
                ),
                _choiceChip(
                  '9:16 Center Crop',
                  _aspectMode == '9:16_crop',
                  () => setState(() => _aspectMode = '9:16_crop'),
                ),
                _choiceChip(
                  '9:16 Blur BG',
                  _aspectMode == '9:16_blur',
                  () => setState(() => _aspectMode = '9:16_blur'),
                ),
                _choiceChip(
                  '16:9 Original',
                  _aspectMode == 'original',
                  () => setState(() => _aspectMode = 'original'),
                ),
              ],
            ),

            if (_aspectMode == 'streamer_split') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green.withAlpha(110)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.crop_free, color: AppColors.green, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Upar green FACECAM box ko drag karke streamer ke chehre par rakho (sabhi selected clips par apply hoga)',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _miniBtn('Right Mid',
                            () => _applyCornerPreset('mid_right')),
                        _miniBtn('Top-Right',
                            () => _applyCornerPreset('top_right')),
                        _miniBtn(
                            'Top-Left', () => _applyCornerPreset('top_left')),
                        _miniBtn('Bot-Left',
                            () => _applyCornerPreset('bottom_left')),
                        _miniBtn('Bot-Right',
                            () => _applyCornerPreset('bottom_right')),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 74,
                            child: Text('Box Width',
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                          child: Slider(
                            value: _camW,
                            min: 0.12,
                            max: 0.55,
                            activeColor: AppColors.green,
                            onChanged: (v) => setState(() {
                              _camW = v;
                              _camX = _camX.clamp(
                                  0.0, (1.0 - _camW).clamp(0.0, 0.90));
                            }),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 74,
                            child: Text('Box Height',
                                style: TextStyle(fontSize: 12))),
                        Expanded(
                          child: Slider(
                            value: _camH,
                            min: 0.14,
                            max: 0.65,
                            activeColor: AppColors.green,
                            onChanged: (v) => setState(() {
                              _camH = v;
                              _camY = _camY.clamp(
                                  0.0, (1.0 - _camH).clamp(0.0, 0.90));
                            }),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        _choiceChip('42% Face / 58% Game',
                            _topSplitHeight == 538,
                            () => setState(() => _topSplitHeight = 538)),
                        _choiceChip('50% / 50%', _topSplitHeight == 640,
                            () => setState(() => _topSplitHeight = 640)),
                        _choiceChip('35% Face / 65% Game',
                            _topSplitHeight == 448,
                            () => setState(() => _topSplitHeight = 448)),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            if (_processing) ...[
              LinearProgressIndicator(
                value: _exportProgress > 0 && _exportProgress < 1
                    ? _exportProgress
                    : null,
                color: AppColors.pink,
                backgroundColor: AppColors.surfaceLight,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  onPressed: _cancelQueue,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Cancel Queue'),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  foregroundColor: Colors.white,
                ),
                onPressed: _processing ? null : _exportQueue,
                icon: const Icon(Icons.movie_filter),
                label: Text(_manualMode
                    ? 'Export Custom Clip'
                    : 'Export $selectedCount Selected Viral Clips'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.purple.withAlpha(110)),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
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
        fontSize: 12,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

// ============================================================================
// TOOL 2: STREAMER SPLIT (GALLERY VIDEO + AUDIO HYPE GRAPH + DRAGGABLE CAM BOX)
// ============================================================================
class StreamerSplitScreen extends StatefulWidget {
  const StreamerSplitScreen({super.key});

  @override
  State<StreamerSplitScreen> createState() => _StreamerSplitScreenState();
}

class _StreamerSplitScreenState extends State<StreamerSplitScreen> {
  String? _videoPath;
  VideoPlayerController? _player;
  double _totalSeconds = 60;
  double _currentPlaySec = 0;

  bool _scanning = false;
  bool _processing = false;
  bool _cancelRequested = false;
  String _statusText = '';

  List<ViralGraphPoint> _graphPoints = [];
  List<ViralClipCandidate> _viralClips = [];
  double _clipSec = 30.0;

  double _camX = 0.74;
  double _camY = 0.14;
  double _camW = 0.24;
  double _camH = 0.28;
  int _topSplitHeight = 538;

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted || _player == null || !_player!.value.isInitialized) return;
    final p = _player!.value.position.inMilliseconds / 1000.0;
    if ((p - _currentPlaySec).abs() >= 0.4) {
      setState(() => _currentPlaySec = p.clamp(0.0, _totalSeconds));
    }
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res != null && res.files.single.path != null) {
      final path = res.files.single.path!;
      _player?.removeListener(_onTick);
      _player?.dispose();

      final ctrl = VideoPlayerController.file(File(path));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      ctrl.addListener(_onTick);
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      final dur = ctrl.value.duration.inSeconds.toDouble();
      setState(() {
        _videoPath = path;
        _player = ctrl;
        _totalSeconds = dur < 2 ? 2.0 : dur;
        _currentPlaySec = 0;
        _graphPoints = [];
        _viralClips = [];
      });
    }
  }

  Future<void> _scanAudioGraph() async {
    if (_videoPath == null || _scanning) return;
    _player?.pause();
    setState(() {
      _scanning = true;
      _statusText = 'Audio Hype Graph scan ho raha hai...';
    });

    try {
      final pts = await ViralGraphEngine.scanAudioHypeGraph(_videoPath!);
      if (!mounted) return;
      if (pts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio graph detect nahi ho paya.')),
        );
      } else {
        final clips = ViralGraphEngine.detectViralClips(
          points: pts,
          totalSeconds: _totalSeconds,
          clipDurationSec: _clipSec,
        );
        setState(() {
          _graphPoints = pts;
          _viralClips = clips;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _statusText = '';
        });
      }
    }
  }

  void _seekTo(double sec) {
    final t = sec.clamp(0.0, _totalSeconds);
    setState(() => _currentPlaySec = t);
    _player?.seekTo(Duration(milliseconds: (t * 1000).round()));
    if (_player != null && !_player!.value.isPlaying) _player!.play();
  }

  void _applyCorner(String corner) {
    setState(() {
      switch (corner) {
        case 'top_right':
          _camX = (1.0 - _camW - 0.01).clamp(0.0, 0.85);
          _camY = 0.02;
          break;
        case 'mid_right':
          _camX = (1.0 - _camW - 0.01).clamp(0.0, 0.85);
          _camY = 0.14;
          break;
        case 'top_left':
          _camX = 0.01;
          _camY = 0.02;
          break;
        case 'bottom_left':
          _camX = 0.01;
          _camY = (1.0 - _camH - 0.02).clamp(0.0, 0.85);
          break;
        case 'bottom_right':
          _camX = (1.0 - _camW - 0.01).clamp(0.0, 0.85);
          _camY = (1.0 - _camH - 0.02).clamp(0.0, 0.85);
          break;
      }
    });
  }

  Future<void> _exportSplit() async {
    if (_videoPath == null) return;
    _player?.pause();
    _cancelRequested = false;

    final selectedClips = _viralClips.where((c) => c.selected).toList();
    setState(() {
      _processing = true;
      _statusText = selectedClips.isEmpty
          ? 'Full Streamer Split render ho raha hai...'
          : 'Exporting ${selectedClips.length} viral clips...';
    });

    final exported = <String>[];
    String? lastDl;
    try {
      final fc = StudioStorage.buildStreamerSplitFilter(
        camX: _camX,
        camY: _camY,
        camW: _camW,
        camH: _camH,
        topHeight: _topSplitHeight,
      );

      if (selectedClips.isEmpty) {
        final out = await StudioStorage.newOutputPath('streamer_split');
        final cmd = '-y -i "$_videoPath" -filter_complex "$fc" '
            '-map "[v]" -map 0:a? -c:v mpeg4 -q:v 3 -c:a aac "$out"';
        final session = await FFmpegKit.execute(cmd);
        if (ReturnCode.isSuccess(await session.getReturnCode())) {
          exported.add(out);
          lastDl = await StudioStorage.mirrorToDownloads(out);
        }
      } else {
        for (int i = 0; i < selectedClips.length; i++) {
          if (_cancelRequested) break;
          final c = selectedClips[i];
          final dur = (c.endSec - c.startSec).clamp(1.0, _totalSeconds);
          if (mounted) {
            setState(() => _statusText =
                'Exporting Clip ${i + 1} / ${selectedClips.length}...');
          }
          final out =
              await StudioStorage.newOutputPath('streamer_viral_r${c.rank}');
          final cmd =
              '-y -ss ${c.startSec.toStringAsFixed(1)} -i "$_videoPath" '
              '-t ${dur.toStringAsFixed(1)} -filter_complex "$fc" '
              '-map "[v]" -map 0:a? -c:v mpeg4 -q:v 3 -c:a aac "$out"';
          final session = await FFmpegKit.execute(cmd);
          if (ReturnCode.isSuccess(await session.getReturnCode())) {
            exported.add(out);
            lastDl = await StudioStorage.mirrorToDownloads(out);
          }
        }
      }

      if (!mounted) return;
      if (exported.length == 1) {
        _showExportSuccessDialog(context, exported.first, lastDl);
      } else if (exported.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${exported.length} Streamer Split clips Projects tab mein save ho gayi!'),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Streamer Split export fail/cancel hua.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _statusText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _viralClips.where((c) => c.selected).length;

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
            const SizedBox(height: 14),
            VideoWithFacecamSelector(
              controller: _player,
              showFacecamBox: true,
              camX: _camX,
              camY: _camY,
              camW: _camW,
              camH: _camH,
              onDragBox: (nx, ny) => setState(() {
                _camX = nx;
                _camY = ny;
              }),
            ),
            const SizedBox(height: 10),

            // Optional Offline Audio Hype Scanner for Gallery Streams
            OutlinedButton.icon(
              onPressed: (_scanning || _processing) ? null : _scanAudioGraph,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.graphic_eq, color: AppColors.cyan),
              label: Text(_scanning
                  ? 'Audio Hype Scan Ho Raha Hai...'
                  : 'Scan Audio Hype Graph (Auto Viral Clips)'),
            ),

            if (_graphPoints.isNotEmpty) ...[
              const SizedBox(height: 10),
              ViralGraphWidget(
                points: _graphPoints,
                clips: _viralClips,
                totalSeconds: _totalSeconds,
                currentSec: _currentPlaySec,
                onSeek: _seekTo,
              ),
              const SizedBox(height: 8),
              Text(
                '${_viralClips.length} Hype Clips mili ($selectedCount selected)',
                style: const TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [30.0, 60.0].map((s) {
                  return ChoiceChip(
                    label: Text('${s.round()}s'),
                    selected: _clipSec == s,
                    selectedColor: AppColors.purple,
                    onSelected: (_) {
                      setState(() {
                        _clipSec = s;
                        _viralClips = ViralGraphEngine.detectViralClips(
                          points: _graphPoints,
                          totalSeconds: _totalSeconds,
                          clipDurationSec: _clipSec,
                        );
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              ..._viralClips.take(10).map((c) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.pink,
                    value: c.selected,
                    onChanged: (v) => setState(() => c.selected = v ?? false),
                    title: Text(
                      'Clip #${c.rank} • ${c.viralScorePct}% Hype (${StudioStorage.formatSeconds(c.startSec)} - ${StudioStorage.formatSeconds(c.endSec)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: IconButton(
                      icon: const Icon(Icons.play_circle,
                          color: AppColors.cyan),
                      onPressed: () => _seekTo(c.startSec),
                    ),
                  )),
            ],

            const SizedBox(height: 12),
            const Text(
              'Green FACECAM box ko khiska kar streamer ke chehre par set karo:',
              style: TextStyle(
                  color: AppColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                    label: const Text('Right Mid'),
                    onPressed: () => _applyCorner('mid_right')),
                ActionChip(
                    label: const Text('Top-Right'),
                    onPressed: () => _applyCorner('top_right')),
                ActionChip(
                    label: const Text('Top-Left'),
                    onPressed: () => _applyCorner('top_left')),
                ActionChip(
                    label: const Text('Bot-Left'),
                    onPressed: () => _applyCorner('bottom_left')),
                ActionChip(
                    label: const Text('Bot-Right'),
                    onPressed: () => _applyCorner('bottom_right')),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 74, child: Text('Box Width')),
                Expanded(
                  child: Slider(
                    value: _camW,
                    min: 0.12,
                    max: 0.55,
                    activeColor: AppColors.green,
                    onChanged: (v) => setState(() {
                      _camW = v;
                      _camX = _camX.clamp(0.0, (1.0 - _camW).clamp(0.0, 0.90));
                    }),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 74, child: Text('Box Height')),
                Expanded(
                  child: Slider(
                    value: _camH,
                    min: 0.14,
                    max: 0.65,
                    activeColor: AppColors.green,
                    onChanged: (v) => setState(() {
                      _camH = v;
                      _camY = _camY.clamp(0.0, (1.0 - _camH).clamp(0.0, 0.90));
                    }),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('42% Face / 58% Game'),
                  selected: _topSplitHeight == 538,
                  selectedColor: AppColors.pink,
                  onSelected: (_) => setState(() => _topSplitHeight = 538),
                ),
                ChoiceChip(
                  label: const Text('50% / 50%'),
                  selected: _topSplitHeight == 640,
                  selectedColor: AppColors.pink,
                  onSelected: (_) => setState(() => _topSplitHeight = 640),
                ),
              ],
            ),
            if (_statusText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.cyan, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pink,
                foregroundColor: Colors.white,
              ),
              onPressed: _processing ? null : _exportSplit,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.splitscreen),
              label: Text(_processing
                  ? 'Rendering...'
                  : (selectedCount > 0
                      ? 'Export $selectedCount Hype Clips (9:16)'
                      : 'Export Full Streamer Split (9:16)')),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// TOOL 3: VICE GAMING CLIPPER
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
// TOOL 4: AUTO-SPLIT SHORTS (30s / 60s)
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
        Navigator.of(context).pop(true);
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
// TAB 2: PROJECTS TAB (SAVED EXPORTS)
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
                'Viral Clip Studio v2.4',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '100% Free Test Build • Viral Graph + Live Player + Streamer Split',
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
