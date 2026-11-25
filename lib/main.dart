import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
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
  static const viceOrange = Color(0xFFFF6B35);
}

// ============================================================================
// PREMIUM VIDEO EFFECTS PRESETS (14 Presets incl. Vice Neon & Miami Sunset)
// ============================================================================
class VideoEffectPreset {
  final String id;
  final String name;
  final String category;
  final Color accent;
  final IconData icon;
  final String ffmpegFilter;
  final List<double> previewMatrix;
  final double previewBlur;

  const VideoEffectPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.accent,
    required this.icon,
    required this.ffmpegFilter,
    required this.previewMatrix,
    this.previewBlur = 0.0,
  });
}

const List<double> _identityMatrix = [
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

const List<VideoEffectPreset> kStudioEffects = [
  VideoEffectPreset(
    id: 'none',
    name: 'Original',
    category: 'Basic',
    accent: Colors.white70,
    icon: Icons.block_rounded,
    ffmpegFilter: '',
    previewMatrix: _identityMatrix,
  ),
  VideoEffectPreset(
    id: 'vice_neon',
    name: 'Vice Neon',
    category: 'Gaming',
    accent: Color(0xFFFF2E93),
    icon: Icons.sports_esports_rounded,
    ffmpegFilter:
        'colorbalance=rs=0.10:gs=-0.04:bs=0.16:rh=0.16:gh=-0.02:bh=0.14,eq=contrast=1.24:saturation=1.55:brightness=0.03,unsharp=5:5:0.9',
    previewMatrix: [
      1.32, 0, 0.14, 0, 10,
      0, 1.02, 0.08, 0, 0,
      0.14, 0.06, 1.36, 0, 14,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'miami_sunset',
    name: 'Miami Sunset',
    category: 'Gaming',
    accent: Color(0xFFFF6B35),
    icon: Icons.wb_twilight_rounded,
    ffmpegFilter:
        'colorbalance=rs=-0.06:gs=0.02:bs=0.14:rh=0.22:gh=0.08:bh=-0.06,eq=contrast=1.20:saturation=1.45:brightness=0.04,unsharp=5:5:0.8',
    previewMatrix: [
      1.34, 0.08, 0, 0, 14,
      0.04, 1.08, 0.02, 0, 6,
      0, 0.04, 1.12, 0, 6,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'neon_glow',
    name: 'Neon Glow',
    category: 'Trending',
    accent: Color(0xFFE02BFF),
    icon: Icons.bolt_rounded,
    ffmpegFilter:
        'eq=contrast=1.22:saturation=1.65:brightness=0.04,colorbalance=rs=0.08:bs=0.18:rm=0.10:bm=0.14,unsharp=5:5:0.8',
    previewMatrix: [
      1.28, 0, 0.12, 0, 8,
      0, 1.05, 0.08, 0, 2,
      0.16, 0.05, 1.38, 0, 14,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'cinematic',
    name: 'Cinematic',
    category: 'Cinematic',
    accent: Color(0xFF00E5FF),
    icon: Icons.movie_filter_rounded,
    ffmpegFilter:
        'colorbalance=rs=-0.08:gs=0.02:bs=0.14:rh=0.14:gh=0.04:bh=-0.08,eq=contrast=1.18:saturation=1.22,vignette=PI/4',
    previewMatrix: [
      1.18, 0.04, -0.06, 0, -4,
      0, 1.06, 0.04, 0, 0,
      -0.06, 0.06, 1.18, 0, 6,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'rgb_glitch',
    name: 'RGB Glitch',
    category: 'Trending',
    accent: Color(0xFF00F0FF),
    icon: Icons.grain_rounded,
    ffmpegFilter: 'rgbashift=rh=9:bh=-9:gh=-3:rv=2,eq=contrast=1.25:saturation=1.45',
    previewMatrix: [
      1.30, -0.08, 0.10, 0, 5,
      -0.05, 1.15, 0.08, 0, 0,
      0.12, -0.06, 1.32, 0, 8,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'vhs_retro',
    name: 'VHS Retro',
    category: 'Retro',
    accent: Color(0xFFF59E0B),
    icon: Icons.videocam_rounded,
    ffmpegFilter:
        'rgbashift=rh=4:bh=-4:rv=1:bv=-1,noise=alls=14:allf=t+u,eq=saturation=0.88:contrast=1.12,vignette=PI/4',
    previewMatrix: [
      1.08, 0.08, 0.02, 0, 8,
      0.04, 0.98, 0.04, 0, 4,
      0.02, 0.06, 0.88, 0, 10,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'vintage',
    name: 'Vintage Film',
    category: 'Retro',
    accent: Color(0xFFD97706),
    icon: Icons.camera_roll_rounded,
    ffmpegFilter:
        'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131,eq=contrast=1.08:brightness=0.03,vignette=PI/3.5',
    previewMatrix: [
      0.45, 0.72, 0.18, 0, 8,
      0.34, 0.68, 0.16, 0, 4,
      0.26, 0.50, 0.14, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'dream_glow',
    name: 'Dream Glow',
    category: 'Trending',
    accent: Color(0xFFF472B6),
    icon: Icons.flare_rounded,
    ffmpegFilter: 'gblur=sigma=1.5,eq=brightness=0.06:contrast=1.10:saturation=1.28',
    previewMatrix: [
      1.12, 0.04, 0.04, 0, 14,
      0.03, 1.08, 0.04, 0, 12,
      0.04, 0.04, 1.14, 0, 14,
      0, 0, 0, 1, 0,
    ],
    previewBlur: 1.5,
  ),
  VideoEffectPreset(
    id: 'fire_warm',
    name: 'Fire Warm',
    category: 'Cinematic',
    accent: Color(0xFFFF5722),
    icon: Icons.local_fire_department_rounded,
    ffmpegFilter:
        'colorbalance=rs=0.16:gs=0.04:bs=-0.12:rh=0.18:gh=0.05:bh=-0.10,eq=contrast=1.18:saturation=1.38',
    previewMatrix: [
      1.32, 0.06, 0, 0, 12,
      0.04, 1.06, 0, 0, 4,
      0, 0, 0.80, 0, -8,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'cyber_cold',
    name: 'Cyber Cold',
    category: 'Cinematic',
    accent: Color(0xFF38BDF8),
    icon: Icons.ac_unit_rounded,
    ffmpegFilter:
        'colorbalance=rs=-0.12:gs=0.02:bs=0.16:rm=-0.06:bm=0.14,eq=contrast=1.16:saturation=1.25',
    previewMatrix: [
      0.86, 0, 0, 0, -6,
      0, 1.06, 0.05, 0, 2,
      0.04, 0.08, 1.32, 0, 12,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'soft_blur',
    name: 'Soft Blur',
    category: 'Basic',
    accent: Color(0xFF818CF8),
    icon: Icons.blur_on_rounded,
    ffmpegFilter: 'gblur=sigma=5',
    previewMatrix: _identityMatrix,
    previewBlur: 4.5,
  ),
  VideoEffectPreset(
    id: 'noir_bw',
    name: 'Noir B&W',
    category: 'Retro',
    accent: Colors.grey,
    icon: Icons.contrast_rounded,
    ffmpegFilter: 'hue=s=0,eq=contrast=1.32:brightness=-0.03,vignette=PI/4',
    previewMatrix: [
      0.38, 0.72, 0.14, 0, -18,
      0.38, 0.72, 0.14, 0, -18,
      0.38, 0.72, 0.14, 0, -18,
      0, 0, 0, 1, 0,
    ],
  ),
  VideoEffectPreset(
    id: 'hdr_vivid',
    name: 'HDR Vivid',
    category: 'Gaming',
    accent: Color(0xFF10B981),
    icon: Icons.hd_rounded,
    ffmpegFilter: 'eq=contrast=1.22:saturation=1.48:brightness=0.03,unsharp=5:5:1.0',
    previewMatrix: [
      1.28, -0.08, -0.04, 0, 4,
      -0.06, 1.28, -0.06, 0, 4,
      -0.04, -0.08, 1.28, 0, 4,
      0, 0, 0, 1, 0,
    ],
  ),
];

// ============================================================================
// PREMIUM PHOTO-TO-VIDEO TRANSITION PRESETS (FFmpeg xfade)
// ============================================================================
class TransitionPreset {
  final String id;
  final String name;
  final String tag;
  final IconData icon;
  final Color color;
  final List<String> xfadeNames;

  const TransitionPreset({
    required this.id,
    required this.name,
    required this.tag,
    required this.icon,
    required this.color,
    required this.xfadeNames,
  });
}

const List<TransitionPreset> kStudioTransitions = [
  TransitionPreset(
    id: 'auto_mix',
    name: 'Auto Pro Mix',
    tag: '1-Click Viral',
    icon: Icons.auto_awesome_rounded,
    color: AppColors.neonPink,
    xfadeNames: [
      'smoothleft',
      'circleopen',
      'zoomin',
      'fadeblack',
      'radial',
      'wipeup',
      'dissolve',
      'smoothright',
    ],
  ),
  TransitionPreset(
    id: 'zoomin',
    name: 'Zoom Pulse',
    tag: 'Reels Hit',
    icon: Icons.zoom_in_rounded,
    color: AppColors.neonCyan,
    xfadeNames: ['zoomin'],
  ),
  TransitionPreset(
    id: 'smoothleft',
    name: 'Smooth Swipe',
    tag: 'Clean',
    icon: Icons.swipe_left_rounded,
    color: AppColors.neonPurple,
    xfadeNames: ['smoothleft', 'smoothright'],
  ),
  TransitionPreset(
    id: 'circleopen',
    name: 'Circle Spotlight',
    tag: 'Premium',
    icon: Icons.circle_outlined,
    color: Color(0xFFF59E0B),
    xfadeNames: ['circleopen', 'circleclose'],
  ),
  TransitionPreset(
    id: 'fadeblack',
    name: 'Cinema Fade',
    tag: 'Movie',
    icon: Icons.movie_rounded,
    color: Color(0xFF60A5FA),
    xfadeNames: ['fadeblack'],
  ),
  TransitionPreset(
    id: 'dissolve',
    name: 'Silk Dissolve',
    tag: 'Romantic',
    icon: Icons.blur_linear_rounded,
    color: Color(0xFFF472B6),
    xfadeNames: ['dissolve'],
  ),
  TransitionPreset(
    id: 'radial',
    name: 'Radial Spin',
    tag: 'Dynamic',
    icon: Icons.motion_photos_on_rounded,
    color: Color(0xFF10B981),
    xfadeNames: ['radial'],
  ),
  TransitionPreset(
    id: 'pixelize',
    name: 'Glitch Pixel',
    tag: 'Gaming',
    icon: Icons.grid_on_rounded,
    color: Color(0xFFEC4899),
    xfadeNames: ['pixelize'],
  ),
  TransitionPreset(
    id: 'wipeup',
    name: 'Curtain Wipe',
    tag: 'Story',
    icon: Icons.vertical_align_top_rounded,
    color: Color(0xFF38BDF8),
    xfadeNames: ['wipeup', 'wipedown'],
  ),
  TransitionPreset(
    id: 'diagtl',
    name: 'Diagonal Slice',
    tag: 'Action',
    icon: Icons.call_made_rounded,
    color: Color(0xFFA855F7),
    xfadeNames: ['diagtl', 'diagbr'],
  ),
  TransitionPreset(
    id: 'horzopen',
    name: 'Shutter Open',
    tag: 'Reveal',
    icon: Icons.unfold_more_rounded,
    color: Color(0xFFFF7043),
    xfadeNames: ['horzopen', 'vertopen'],
  ),
  TransitionPreset(
    id: 'slideleft',
    name: 'Fast Slide',
    tag: 'Trend',
    icon: Icons.fast_forward_rounded,
    color: Color(0xFF22D3EE),
    xfadeNames: ['slideleft', 'slideup'],
  ),
];

// ============================================================================
// BUILT-IN COPYRIGHT-FREE STUDIO MUSIC PACKS & GAMING SFX
// ============================================================================
class BuiltInMusicTrack {
  final String id;
  final String title;
  final String mood;
  final int bpm;
  final Color color;
  final List<List<int>> chords;
  final List<int> melody;
  final bool hasKick;
  final bool hasHat;
  final bool brightSynth;

  const BuiltInMusicTrack({
    required this.id,
    required this.title,
    required this.mood,
    required this.bpm,
    required this.color,
    required this.chords,
    required this.melody,
    required this.hasKick,
    required this.hasHat,
    required this.brightSynth,
  });
}

const List<BuiltInMusicTrack> kBuiltInMusicTracks = [
  BuiltInMusicTrack(
    id: 'lofi_chill',
    title: 'Lo-Fi Chill Night',
    mood: 'Vlog / Study',
    bpm: 84,
    color: Color(0xFFA855F7),
    chords: [
      [53, 57, 60, 64],
      [52, 55, 59, 62],
      [50, 53, 57, 60],
      [48, 52, 55, 59],
    ],
    melody: [72, 0, 76, 74, 72, 0, 69, 0, 71, 0, 74, 72, 67, 0, 69, 0],
    hasKick: true,
    hasHat: true,
    brightSynth: false,
  ),
  BuiltInMusicTrack(
    id: 'viral_hype',
    title: 'Viral Reels Hype',
    mood: 'Shorts / Gym',
    bpm: 124,
    color: Color(0xFFEC4899),
    chords: [
      [45, 52, 57, 60],
      [41, 48, 53, 57],
      [48, 55, 60, 64],
      [43, 50, 55, 59],
    ],
    melody: [69, 72, 76, 0, 74, 72, 69, 0, 72, 76, 79, 0, 76, 74, 72, 69],
    hasKick: true,
    hasHat: true,
    brightSynth: true,
  ),
  BuiltInMusicTrack(
    id: 'cinematic_epic',
    title: 'Cinematic Epic Rise',
    mood: 'Movie / Travel',
    bpm: 92,
    color: Color(0xFF0EA5E9),
    chords: [
      [45, 52, 57, 64],
      [41, 48, 53, 60],
      [43, 50, 55, 62],
      [45, 52, 57, 64],
    ],
    melody: [64, 0, 69, 0, 72, 0, 71, 69, 67, 0, 71, 0, 76, 0, 74, 0],
    hasKick: true,
    hasHat: false,
    brightSynth: false,
  ),
  BuiltInMusicTrack(
    id: 'happy_reels',
    title: 'Happy Reels Pop',
    mood: 'Lifestyle / Fun',
    bpm: 118,
    color: Color(0xFFF59E0B),
    chords: [
      [48, 55, 60, 64],
      [43, 50, 55, 59],
      [45, 52, 57, 60],
      [41, 48, 53, 57],
    ],
    melody: [72, 76, 79, 76, 74, 71, 74, 79, 76, 72, 69, 72, 74, 77, 76, 72],
    hasKick: true,
    hasHat: true,
    brightSynth: true,
  ),
  BuiltInMusicTrack(
    id: 'romantic_piano',
    title: 'Romantic Wedding Piano',
    mood: 'Wedding / Love',
    bpm: 76,
    color: Color(0xFFF472B6),
    chords: [
      [48, 55, 60, 64],
      [45, 52, 57, 60],
      [41, 48, 53, 57],
      [43, 50, 55, 59],
    ],
    melody: [64, 67, 72, 71, 69, 72, 76, 72, 69, 72, 74, 72, 71, 67, 74, 71],
    hasKick: false,
    hasHat: false,
    brightSynth: false,
  ),
  BuiltInMusicTrack(
    id: 'neon_cyber',
    title: 'Neon Cyberpunk Wave',
    mood: 'Gaming / Edit',
    bpm: 114,
    color: Color(0xFF00F0FF),
    chords: [
      [40, 47, 52, 55],
      [43, 50, 55, 59],
      [45, 52, 57, 60],
      [47, 54, 59, 62],
    ],
    melody: [64, 67, 71, 76, 74, 71, 67, 71, 69, 72, 76, 72, 71, 74, 78, 74],
    hasKick: true,
    hasHat: true,
    brightSynth: true,
  ),
  BuiltInMusicTrack(
    id: 'podcast_motivate',
    title: 'Motivational Podcast',
    mood: 'Quotes / Story',
    bpm: 96,
    color: Color(0xFF10B981),
    chords: [
      [50, 57, 62, 65],
      [46, 53, 58, 62],
      [48, 55, 60, 64],
      [45, 52, 57, 61],
    ],
    melody: [69, 0, 74, 0, 70, 0, 74, 72, 72, 0, 76, 0, 73, 0, 69, 0],
    hasKick: true,
    hasHat: false,
    brightSynth: false,
  ),
  BuiltInMusicTrack(
    id: 'birthday_party',
    title: 'Celebration & Birthday',
    mood: 'Party / Status',
    bpm: 120,
    color: Color(0xFFFF7043),
    chords: [
      [53, 57, 60, 65],
      [48, 55, 60, 64],
      [50, 57, 62, 65],
      [46, 53, 58, 62],
    ],
    melody: [72, 72, 74, 72, 77, 76, 0, 72, 72, 74, 72, 79, 77, 0, 74, 72],
    hasKick: true,
    hasHat: true,
    brightSynth: true,
  ),
];

Uint8List _encodeMonoWav(Int16List pcm, int sampleRate) {
  final int dataBytes = pcm.length * 2;
  final ByteData header = ByteData(44);
  header.setUint32(0, 0x52494646, Endian.big);
  header.setUint32(4, 36 + dataBytes, Endian.little);
  header.setUint32(8, 0x57415645, Endian.big);
  header.setUint32(12, 0x666d7420, Endian.big);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  header.setUint32(36, 0x64617461, Endian.big);
  header.setUint32(40, dataBytes, Endian.little);

  final Uint8List out = Uint8List(44 + dataBytes);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, 44 + dataBytes, pcm.buffer.asUint8List());
  return out;
}

class StudioMusicPackManager {
  static Future<Directory> _packDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/studio_music_packs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> trackFilePath(BuiltInMusicTrack track) async {
    final dir = await _packDir();
    return '${dir.path}/${track.id}.wav';
  }

  static Future<bool> isDownloaded(BuiltInMusicTrack track) async {
    final path = await trackFilePath(track);
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 10000;
  }

  static Future<String> ensureDownloaded(BuiltInMusicTrack track) async {
    final path = await trackFilePath(track);
    final file = File(path);
    if (file.existsSync() && file.lengthSync() > 10000) {
      return path;
    }
    final wavBytes = _synthesizeStudioLoop(track);
    await file.writeAsBytes(wavBytes, flush: true);
    return path;
  }

  static double _midiToHz(int midi) {
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0).toDouble();
  }

  static Uint8List _synthesizeStudioLoop(BuiltInMusicTrack track) {
    const int sampleRate = 22050;
    final double beatSec = 60.0 / track.bpm;
    final double barSec = beatSec * 4.0;
    final double totalSec = barSec * 4.0;
    final int numSamples = (totalSec * sampleRate).round();

    final Int16List pcm = Int16List(numSamples);
    final rng = math.Random(track.id.hashCode);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final int barIdx = ((t / barSec).floor()).clamp(0, 3);
      final double barLocalT = t - (barIdx * barSec);
      final double beatPos = t / beatSec;
      final double beatLocalT = (beatPos - beatPos.floor()) * beatSec;

      double sample = 0.0;

      final chord = track.chords[barIdx];
      final double padEnv =
          math.min(1.0, barLocalT / 0.12) * math.min(1.0, (barSec - barLocalT) / 0.15 + 0.35);
      for (int c = 0; c < chord.length; c++) {
        final hz = _midiToHz(chord[c]);
        final phase = 2.0 * math.pi * hz * t;
        final tone = math.sin(phase) +
            (track.brightSynth ? 0.28 * math.sin(phase * 2.0) : 0.15 * math.sin(phase * 2.0));
        sample += tone * (c == 0 ? 0.16 : 0.085) * padEnv;
      }

      final int stepIdx = ((t / (barSec / 4.0)).floor()) % track.melody.length;
      final int melMidi = track.melody[stepIdx];
      if (melMidi > 0) {
        final double stepDur = barSec / 4.0;
        final double stepLocalT = t % stepDur;
        final double attack = math.min(1.0, stepLocalT / 0.015);
        final double decay = math.exp(-stepLocalT * (track.brightSynth ? 5.5 : 3.2));
        final double mHz = _midiToHz(melMidi);
        final double mPhase = 2.0 * math.pi * mHz * t;
        final double melWave = math.sin(mPhase) + 0.22 * math.sin(mPhase * 2.0);
        sample += melWave * 0.20 * attack * decay;
      }

      if (track.hasKick) {
        final double kickEnv = math.exp(-beatLocalT * 16.0);
        final double kickFreq = 46.0 + 88.0 * math.exp(-beatLocalT * 30.0);
        sample += math.sin(2.0 * math.pi * kickFreq * beatLocalT) * 0.36 * kickEnv;
      }

      if (track.hasHat) {
        final double halfBeat = beatSec * 0.5;
        final double hatLocalT = t % halfBeat;
        if (hatLocalT < 0.045) {
          final double noise = (rng.nextDouble() * 2.0 - 1.0);
          sample += noise * 0.09 * math.exp(-hatLocalT * 75.0);
        }
      }

      double edgeGain = 1.0;
      if (i < 400) edgeGain = i / 400.0;
      if (i > numSamples - 400) edgeGain = (numSamples - i) / 400.0;

      final double limited = sample / (1.0 + sample.abs() * 0.55);
      pcm[i] = (limited * edgeGain * 29000.0).round().clamp(-32767, 32767);
    }

    return _encodeMonoWav(pcm, sampleRate);
  }
}

// Synthesizes Dramatic Gaming Freeze SFX (Bass Drop / Mission Clear Fanfare)
class StudioGamingSfxGenerator {
  static Future<String> generateFreezeSfx({required bool isFailStyle}) async {
    const int sampleRate = 22050;
    const double durSec = 3.0;
    final int numSamples = (durSec * sampleRate).round();
    final Int16List pcm = Int16List(numSamples);

    if (isFailStyle) {
      // Deep dramatic sub-bass drop + dark tension drone
      double phase = 0.0;
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        final double freq = 38.0 + 115.0 * math.exp(-t * 3.8);
        phase += 2.0 * math.pi * freq / sampleRate;
        final double boom = math.sin(phase) * math.exp(-t * 0.75) * 0.75;
        final double impact = math.sin(2.0 * math.pi * 220.0 * t) * math.exp(-t * 14.0) * 0.30;
        final double drone = (math.sin(2.0 * math.pi * 55.0 * t) + 0.5 * math.sin(2.0 * math.pi * 82.4 * t)) *
            math.min(1.0, t / 0.25) *
            math.exp(-t * 0.6) *
            0.22;
        final double fadeOut = t > 2.4 ? ((3.0 - t) / 0.6).clamp(0.0, 1.0) : 1.0;
        final double s = (boom + impact + drone) * fadeOut;
        pcm[i] = ((s / (1.0 + s.abs() * 0.4)) * 30000.0).round().clamp(-32767, 32767);
      }
    } else {
      // Uplifting Mission Clear golden synth chime chord
      final notes = [261.63, 329.63, 392.00, 523.25];
      final starts = [0.0, 0.16, 0.32, 0.48];
      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        double sample = 0.0;
        for (int n = 0; n < notes.length; n++) {
          if (t >= starts[n]) {
            final dt = t - starts[n];
            final env = math.min(1.0, dt / 0.03) * math.exp(-dt * 1.15);
            final hz = notes[n];
            sample += (math.sin(2.0 * math.pi * hz * dt) + 0.3 * math.sin(4.0 * math.pi * hz * dt)) * 0.28 * env;
          }
        }
        final double fadeOut = t > 2.4 ? ((3.0 - t) / 0.6).clamp(0.0, 1.0) : 1.0;
        pcm[i] = ((sample * fadeOut) * 29000.0).round().clamp(-32767, 32767);
      }
    }

    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/vcs_sfx_${isFailStyle ? "fail" : "win"}_${DateTime.now().millisecondsSinceEpoch}.wav';
    await File(outPath).writeAsBytes(_encodeMonoWav(pcm, sampleRate), flush: true);
    return outPath;
  }
}

// Renders glowing cinematic Freeze-Frame Banner PNG via Flutter Canvas (works on FFmpeg min_gpl!)
Future<String> renderFreezeBannerPng({
  required String titleText,
  required String subtitleText,
  required bool isFailStyle,
}) async {
  const double width = 720;
  const double height = 1280;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  const bandRect = Rect.fromLTWH(0, 510, width, 260);
  final bandPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, 510),
      const Offset(0, 770),
      [
        Colors.black.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.84),
        Colors.black.withValues(alpha: 0.84),
        Colors.black.withValues(alpha: 0.0),
      ],
      const [0.0, 0.18, 0.82, 1.0],
    );
  canvas.drawRect(bandRect, bandPaint);

  final accentColor = isFailStyle ? const Color(0xFFFF2E4C) : const Color(0xFFFFC107);
  final linePaint = Paint()
    ..color = accentColor.withValues(alpha: 0.9)
    ..strokeWidth = 3.5;
  canvas.drawLine(const Offset(80, 555), const Offset(640, 555), linePaint);
  canvas.drawLine(const Offset(80, 725), const Offset(640, 725), linePaint);

  final cleanTitle = titleText.trim().isEmpty
      ? (isFailStyle ? 'BUSTED' : 'MISSION PASSED')
      : titleText.trim().toUpperCase();

  final titlePainter = TextPainter(
    text: TextSpan(
      text: cleanTitle,
      style: TextStyle(
        color: accentColor,
        fontSize: cleanTitle.length > 12 ? 48 : 66,
        fontWeight: FontWeight.w900,
        letterSpacing: 3.0,
        shadows: [
          Shadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 24),
          const Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: width - 64);

  titlePainter.paint(
    canvas,
    Offset((width - titlePainter.width) / 2, 616 - titlePainter.height / 2),
  );

  if (subtitleText.trim().isNotEmpty) {
    final subPainter = TextPainter(
      text: TextSpan(
        text: subtitleText.trim(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width - 80);

    subPainter.paint(
      canvas,
      Offset((width - subPainter.width) / 2, 676),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final tempDir = await getTemporaryDirectory();
  final outPath = '${tempDir.path}/vcs_banner_${DateTime.now().millisecondsSinceEpoch}.png';
  await File(outPath).writeAsBytes(byteData!.buffer.asUint8List(), flush: true);
  return outPath;
}

// ============================================================================
// MEDIA PROBE & OFFLINE HYPE MOMENT SCANNER HELPERS
// ============================================================================
class VideoProbeResult {
  final bool hasAudio;
  final double durationSec;
  const VideoProbeResult({required this.hasAudio, required this.durationSec});
}

Future<VideoProbeResult> probeVideoInfo(String videoPath) async {
  bool hasAudio = false;
  double durationSec = 0.0;
  try {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();
    if (info != null) {
      final durStr = info.getDuration();
      if (durStr != null) {
        durationSec = double.tryParse(durStr) ?? 0.0;
      }
      final streams = info.getStreams();
      if (streams != null) {
        for (final s in streams) {
          if (s.getType() == 'audio') {
            hasAudio = true;
            break;
          }
        }
      }
    }
  } catch (_) {
    hasAudio = true;
  }

  if (durationSec <= 0.1) {
    try {
      final ctrl = VideoPlayerController.file(File(videoPath));
      await ctrl.initialize();
      durationSec = ctrl.value.duration.inMilliseconds / 1000.0;
      await ctrl.dispose();
    } catch (_) {}
  }

  return VideoProbeResult(
    hasAudio: hasAudio,
    durationSec: durationSec > 0.1 ? durationSec : 5.0,
  );
}

Future<bool> checkVideoHasAudio(String videoPath) async {
  final info = await probeVideoInfo(videoPath);
  return info.hasAudio;
}

class HypeMoment {
  final double peakSec;
  final int scorePercent;
  const HypeMoment({required this.peakSec, required this.scorePercent});
}

Future<List<HypeMoment>> scanAudioHypeMoments(String videoPath) async {
  final tempDir = await getTemporaryDirectory();
  final pcmPath = '${tempDir.path}/vcs_hype_scan_${DateTime.now().millisecondsSinceEpoch}.pcm';

  final session = await FFmpegKit.executeWithArguments([
    '-y',
    '-i',
    videoPath,
    '-vn',
    '-ac',
    '1',
    '-ar',
    '1000',
    '-f',
    's16le',
    pcmPath,
  ]);
  final rc = await session.getReturnCode();
  final file = File(pcmPath);
  if (!ReturnCode.isSuccess(rc) || !file.existsSync()) {
    return [];
  }

  final Uint8List bytes = await file.readAsBytes();
  try {
    file.deleteSync();
  } catch (_) {}

  final int totalSamples = bytes.length ~/ 2;
  final int totalSec = totalSamples ~/ 1000;
  if (totalSec < 2) return [];

  final ByteData bd = ByteData.sublistView(bytes);
  final List<double> energies = List<double>.filled(totalSec, 0.0);
  double maxEnergy = 0.0;

  for (int sec = 0; sec < totalSec; sec++) {
    double sumSq = 0.0;
    final int base = sec * 1000;
    for (int k = 0; k < 1000; k++) {
      final int sample = bd.getInt16((base + k) * 2, Endian.little);
      sumSq += sample * sample;
    }
    final double rms = math.sqrt(sumSq / 1000.0);
    energies[sec] = rms;
    if (rms > maxEnergy) maxEnergy = rms;
  }

  if (maxEnergy < 20.0) return [];

  final List<int> indices = List<int>.generate(totalSec, (i) => i);
  indices.sort((a, b) => energies[b].compareTo(energies[a]));

  final int minGap = (totalSec / 6).round().clamp(5, 22);
  final List<HypeMoment> results = [];

  for (final sec in indices) {
    if (results.length >= 8) break;
    final bool tooClose = results.any((m) => (m.peakSec - sec).abs() < minGap);
    if (tooClose) continue;
    final int pct = ((energies[sec] / maxEnergy) * 100).round().clamp(10, 100);
    results.add(HypeMoment(peakSec: sec.toDouble(), scorePercent: pct));
  }

  return results;
}

String formatClock(double seconds) {
  final safe = seconds.isNaN || seconds < 0 ? 0.0 : seconds;
  final d = Duration(milliseconds: (safe * 1000).round());
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
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
// 1. SPLASH SCREEN
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
    _timer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) return;
      setState(() => _progress += 0.05);
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
            colors: [Color(0xFF28124D), Color(0xFF100E24), AppColors.bg],
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
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                    children: [
                      TextSpan(text: 'Viral Clip ', style: TextStyle(color: Colors.white)),
                      TextSpan(
                        text: 'Studio',
                        style: TextStyle(color: AppColors.neonPink, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create  •  Edit  •  Share',
                  style: TextStyle(color: Colors.white70, fontSize: 15, letterSpacing: 1.2),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vice Gaming Clipper • AI Facecam • 60 FPS Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.neonCyan, fontSize: 12),
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
// 2. MAIN SHELL (Home / Projects / Studio Packs / Me)
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

  Future<void> _openNewProject({int initialTool = 0, String? initialEffectId}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    final exportedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => VideoStudioEditorScreen(
          videoPath: result.files.single.path!,
          videoName: result.files.single.name,
          initialToolTab: initialTool,
          initialEffectId: initialEffectId,
        ),
      ),
    );

    if (exportedPath != null) {
      await _saveExportRecord(exportedPath);
    }
  }

  void _openGamingStudio() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamingClipStudioScreen(onExported: _saveExportRecord),
      ),
    );
  }

  void _openPhotoToVideo({String? initialTransitionId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoToVideoStudioScreen(
          initialTransitionId: initialTransitionId,
          onExported: _saveExportRecord,
        ),
      ),
    );
  }

  void _openStreamerSplit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StreamerSplitScreen(onExported: _saveExportRecord),
      ),
    );
  }

  void _openEffectsGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EffectsGalleryScreen(
          onApplyEffect: (effectId) => _openNewProject(
            initialTool: 5,
            initialEffectId: effectId,
          ),
        ),
      ),
    );
  }

  void _openMusicLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StudioMusicLibraryScreen(pickerMode: false),
      ),
    );
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

  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // NEW Hero Banner -> Vice Gaming Studio (Open-World Clipper)
        InkWell(
          onTap: _openGamingStudio,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF831843), Color(0xFFDB2777), Color(0xFFF97316)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDB2777).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Icon(Icons.sports_esports_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vice Gaming Clipper 🎮',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Auto Hype Scan • Fail Freeze SFX • 60 FPS',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: const Text(
                          'Open Gaming Studio →',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2 Big Action Cards (New Project + Live Auto-Split)
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
                title: 'Auto-Split\nLive Preview ✂️',
                icon: Icons.content_cut_rounded,
                colors: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                onTap: _openAutoSplit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Streamer Split (AI Facecam Top + Gameplay Bottom)
        InkWell(
          onTap: _openStreamerSplit,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF3B0764)],
              ),
              border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.face_retouching_natural, color: AppColors.neonCyan, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Streamer Split (AI Facecam)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Facecam upar + Gameplay neeche (9:16 Auto Detect)',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.neonCyan, size: 15),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

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
              label: 'Photo Reels',
              icon: Icons.photo_library_rounded,
              color: const Color(0xFFEC4899),
              onTap: _openPhotoToVideo,
            ),
            _quickToolCard(
              label: 'Effects (14)',
              icon: Icons.auto_fix_high_rounded,
              color: const Color(0xFFFBBF24),
              onTap: _openEffectsGallery,
            ),
            _quickToolCard(
              label: 'Music Packs',
              icon: Icons.music_note_rounded,
              color: const Color(0xFF38BDF8),
              onTap: _openMusicLibrary,
            ),
            _quickToolCard(
              label: 'Merge Clips',
              icon: Icons.merge_type_rounded,
              color: const Color(0xFFA855F7),
              onTap: _openMerger,
            ),
            _quickToolCard(
              label: 'Speed',
              icon: Icons.speed_rounded,
              color: const Color(0xFF10B981),
              onTap: () => _openNewProject(initialTool: 2),
            ),
            _quickToolCard(
              label: 'Crop / Flip',
              icon: Icons.crop_rotate_rounded,
              color: const Color(0xFF60A5FA),
              onTap: () => _openNewProject(initialTool: 1),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (_recentExports.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Exports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        height: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          boxShadow: [
            BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
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
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center),
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

  Widget _buildStudioPacksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Built-In Studio Packs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Gaming Tools, Effects, Music Packs aur Transitions sab app mein active hain:',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _packActionCard(
          title: 'Vice Gaming Clipper Studio',
          subtitle: 'Auto Hype Audio Scan + Fail/Mission Freeze SFX + HUD-Safe 9:16 + 60 FPS',
          icon: Icons.sports_esports_rounded,
          color: AppColors.viceOrange,
          badge: 'NEW v2.2',
          onTap: _openGamingStudio,
        ),
        const SizedBox(height: 12),
        _packActionCard(
          title: 'Streamer Split (AI Facecam)',
          subtitle: 'Auto face detect karke Facecam upar + Gameplay neeche 9:16 Short banayein',
          icon: Icons.face_retouching_natural,
          color: AppColors.neonCyan,
          badge: 'AI',
          onTap: _openStreamerSplit,
        ),
        const SizedBox(height: 12),
        _packActionCard(
          title: '14 Premium Effects & Filters',
          subtitle: 'Vice Neon, Miami Sunset, Neon Glow, Cinematic, VHS Retro, RGB Glitch & more',
          icon: Icons.auto_fix_high_rounded,
          color: const Color(0xFFFBBF24),
          badge: 'ACTIVE',
          onTap: _openEffectsGallery,
        ),
        const SizedBox(height: 12),
        _packActionCard(
          title: '8 Built-In Studio Music Packs',
          subtitle: 'Lo-Fi, Viral Hype, Cinematic, Reels Pop, Wedding Piano, Cyberpunk (Offline Ready)',
          icon: Icons.music_note_rounded,
          color: AppColors.neonBlue,
          badge: 'ACTIVE',
          onTap: _openMusicLibrary,
        ),
        const SizedBox(height: 12),
        _packActionCard(
          title: '12 One-Click Photo Transitions',
          subtitle: 'Auto Pro Mix, Zoom Pulse, Circle Spotlight, Radial Spin, Glitch Pixel + Blur Frame',
          icon: Icons.auto_awesome_motion,
          color: AppColors.neonPink,
          badge: 'ACTIVE',
          onTap: _openPhotoToVideo,
        ),
      ],
    );
  }

  Widget _packActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
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
                  Text('Viral Clip Studio v2.2', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Status: FREE TEST BUILD (Vice Gaming Edition)\nSabhi tools bina kisi paywall ke test karein.',
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
              Text('Active Testing Features:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 10),
              Text('✓ Vice Gaming Clipper: Offline Auto Hype Audio Scanner'),
              Text('✓ 1-Tap Fail Freeze & Mission Clear Ending + Bass SFX'),
              Text('✓ Vice Neon & Miami Sunset Color Grading Presets'),
              Text('✓ HUD-Safe Cinema Blur 9:16 + 60 FPS Smooth Gaming Export'),
              Text('✓ Streamer Split: Offline AI Facecam Top + Gameplay Bottom'),
              Text('✓ Crash-Proof FFmpeg Merger + Auto-Split Live Preview'),
              Text('✓ 8 Built-In Music Packs + 12 One-Click Photo Transitions'),
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
      _buildStudioPacksTab(),
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
                  'TEST v2.2',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
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
          NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'Packs'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. VICE GAMING CLIPPER STUDIO (Hype Scan + Fail/Mission Freeze + 60 FPS)
// ============================================================================
class GamingClipStudioScreen extends StatefulWidget {
  final Future<void> Function(String path) onExported;

  const GamingClipStudioScreen({super.key, required this.onExported});

  @override
  State<GamingClipStudioScreen> createState() => _GamingClipStudioScreenState();
}

class _GamingClipStudioScreenState extends State<GamingClipStudioScreen> {
  String? _videoPath;
  String _videoName = 'Koi gameplay video select nahi hai';
  VideoPlayerController? _controller;
  bool _isVideoReady = false;
  double _totalSec = 1.0;
  RangeValues _clipRange = const RangeValues(0, 1);

  // 1. Offline Auto Hype Scanner
  bool _isScanningHype = false;
  List<HypeMoment> _hypeMoments = [];
  int _selectedHypeIdx = -1;

  // 2. Gaming Layout (cinema_blur / action_zoom)
  String _layoutMode = 'cinema_blur';

  // 3. Color Preset (Default: Vice Neon)
  VideoEffectPreset _selectedEffect = kStudioEffects.firstWhere((e) => e.id == 'vice_neon');

  // 4. Freeze-Frame Ending ('none', 'fail', 'mission')
  String _freezeMode = 'none';
  final TextEditingController _bannerTitleCtrl = TextEditingController(text: 'BUSTED');
  final TextEditingController _bannerSubCtrl = TextEditingController(text: 'BETTER LUCK NEXT TIME');

  // 5. 60 FPS Smooth Gaming Toggle
  bool _use60Fps = true;
  bool _isExporting = false;
  String _exportStatus = '';

  @override
  void dispose() {
    _controller?.dispose();
    _bannerTitleCtrl.dispose();
    _bannerSubCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGameplayVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res == null || res.files.single.path == null) return;

    await _controller?.dispose();
    final path = res.files.single.path!;
    final name = res.files.single.name;

    setState(() {
      _videoPath = path;
      _videoName = name;
      _isVideoReady = false;
      _controller = null;
      _hypeMoments = [];
      _selectedHypeIdx = -1;
    });

    final ctrl = VideoPlayerController.file(File(path));
    await ctrl.initialize();
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    final secs = ctrl.value.duration.inMilliseconds / 1000.0;
    final safeTotal = secs > 1.0 ? secs : 1.0;
    final defaultEnd = math.min(safeTotal, 30.0);

    if (!mounted) {
      await ctrl.dispose();
      return;
    }

    setState(() {
      _controller = ctrl;
      _isVideoReady = true;
      _totalSec = safeTotal;
      _clipRange = RangeValues(0, defaultEnd);
    });
  }

  Future<void> _runHypeScan() async {
    if (_videoPath == null) return;
    setState(() {
      _isScanningHype = true;
      _hypeMoments = [];
      _selectedHypeIdx = -1;
    });

    try {
      final probe = await probeVideoInfo(_videoPath!);
      if (!probe.hasAudio) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Is video mein audio track nahi hai — manual slider se clip select karein.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final moments = await scanAudioHypeMoments(_videoPath!);
      if (!mounted) return;
      setState(() => _hypeMoments = moments);

      if (moments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koi clear loud peak nahi mila — manual range use karein.')),
        );
      } else {
        _jumpToHypeMoment(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanningHype = false);
    }
  }

  Future<void> _jumpToHypeMoment(int idx) async {
    if (idx < 0 || idx >= _hypeMoments.length) return;
    final peak = _hypeMoments[idx].peakSec;
    final double start = math.max(0.0, peak - 12.0);
    final double end = math.min(_totalSec, start + 30.0);
    final double adjustedStart = (end - start < 5.0) ? math.max(0.0, end - 15.0) : start;

    setState(() {
      _selectedHypeIdx = idx;
      _clipRange = RangeValues(adjustedStart, end);
    });

    await _controller?.seekTo(Duration(milliseconds: (adjustedStart * 1000).round()));
    await _controller?.play();
  }

  void _setFreezeMode(String mode) {
    setState(() {
      _freezeMode = mode;
      if (mode == 'fail') {
        _bannerTitleCtrl.text = 'BUSTED';
        _bannerSubCtrl.text = 'EPIC FAIL';
      } else if (mode == 'mission') {
        _bannerTitleCtrl.text = 'MISSION PASSED';
        _bannerSubCtrl.text = 'RESPECT +999';
      }
    });
  }

  void _openFacecamSplitWithCurrentVideo() {
    if (_videoPath == null) return;
    _controller?.pause();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StreamerSplitScreen(
          onExported: widget.onExported,
          initialVideoPath: _videoPath,
          initialVideoName: _videoName,
        ),
      ),
    );
  }

  Future<void> _exportGamingClip() async {
    if (_videoPath == null) return;
    await _controller?.pause();

    setState(() {
      _isExporting = true;
      _exportStatus = 'Gaming clip prepare ho raha hai...';
    });

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      final probe = await probeVideoInfo(_videoPath!);
      final double clipDur = math.max(1.0, _clipRange.end - _clipRange.start);
      final int outFps = _use60Fps ? 60 : 30;
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/vcs_gaming_${DateTime.now().millisecondsSinceEpoch}.mp4';

      String buildLayoutGraph(String inLabel, String outLabel, String extraFilter) {
        final String fxChain = extraFilter.isNotEmpty ? ',$extraFilter' : '';
        if (_layoutMode == 'cinema_blur') {
          return '[$inLabel]split=2[${inLabel}bg][${inLabel}fg];'
              '[${inLabel}bg]scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,gblur=sigma=20[${inLabel}bgb];'
              '[${inLabel}fg]scale=720:1280:force_original_aspect_ratio=decrease[${inLabel}fgs];'
              '[${inLabel}bgb][${inLabel}fgs]overlay=(W-w)/2:(H-h)/2,setsar=1,fps=$outFps$fxChain,format=yuv420p[$outLabel]';
        } else {
          return '[$inLabel]scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,'
              'setsar=1,fps=$outFps$fxChain,format=yuv420p[$outLabel]';
        }
      }

      final List<String> args = ['-y'];

      if (_freezeMode == 'none') {
        setState(() => _exportStatus = 'Rendering ${outFps} FPS Gaming Short...');
        final fc = buildLayoutGraph('0:v', 'vout', _selectedEffect.ffmpegFilter);
        args.addAll([
          '-ss',
          _clipRange.start.toStringAsFixed(2),
          '-i',
          _videoPath!,
          '-t',
          clipDur.toStringAsFixed(2),
          '-filter_complex',
          fc,
          '-map',
          '[vout]',
        ]);

        if (probe.hasAudio) {
          args.addAll(['-map', '0:a', '-c:a', 'aac', '-b:a', '128k']);
        } else {
          args.add('-an');
        }
      } else {
        final bool isFail = _freezeMode == 'fail';
        setState(() => _exportStatus = 'Freeze-Frame banner & SFX ban raha hai...');

        // 1. Extract exact last frame for Freeze-Frame ending
        final double freezeSec = math.max(_clipRange.start, _clipRange.end - 0.12);
        final String freezeImgPath = '${tempDir.path}/vcs_freeze_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final snapSession = await FFmpegKit.executeWithArguments([
          '-y',
          '-ss',
          freezeSec.toStringAsFixed(2),
          '-i',
          _videoPath!,
          '-vframes',
          '1',
          '-q:v',
          '2',
          freezeImgPath,
        ]);
        final snapRc = await snapSession.getReturnCode();
        if (!ReturnCode.isSuccess(snapRc) || !File(freezeImgPath).existsSync()) {
          throw Exception('Freeze frame capture nahi ho paya');
        }

        // 2. Render transparent PNG Banner + Dramatic SFX locally
        final String bannerPngPath = await renderFreezeBannerPng(
          titleText: _bannerTitleCtrl.text,
          subtitleText: _bannerSubCtrl.text,
          isFailStyle: isFail,
        );
        final String sfxPath = await StudioGamingSfxGenerator.generateFreezeSfx(isFailStyle: isFail);

        setState(() => _exportStatus = 'Rendering $outFps FPS clip + 3s Freeze Ending...');

        final String freezeTint = isFail
            ? 'hue=s=0,eq=contrast=1.28:brightness=-0.07,colorbalance=rs=0.22:rm=0.10,vignette=PI/3.5'
            : 'eq=contrast=1.18:saturation=1.35:brightness=0.05,colorbalance=rs=0.14:gs=0.08:bs=-0.10,vignette=PI/4';

        final List<String> filters = [];
        filters.add(buildLayoutGraph('0:v', 'vmain', _selectedEffect.ffmpegFilter));
        filters.add(buildLayoutGraph('1:v', 'vfbase', freezeTint));
        filters.add('[vfbase][2:v]overlay=0:0,setpts=PTS-STARTPTS,format=yuv420p[vfreeze]');

        if (probe.hasAudio) {
          filters.add(
            '[0:a]aformat=sample_rates=44100:channel_layouts=stereo,aresample=async=1,asetpts=PTS-STARTPTS[amain]',
          );
        } else {
          filters.add(
            'anullsrc=channel_layout=stereo:sample_rate=44100,atrim=duration=${clipDur.toStringAsFixed(2)},asetpts=PTS-STARTPTS[amain]',
          );
        }
        filters.add(
          '[3:a]aformat=sample_rates=44100:channel_layouts=stereo,atrim=duration=3.0,asetpts=PTS-STARTPTS[afreeze]',
        );
        filters.add('[vmain]setpts=PTS-STARTPTS[vmain_s]');
        filters.add('[vmain_s][amain][vfreeze][afreeze]concat=n=2:v=1:a=1[vout][aout]');

        args.addAll([
          '-ss',
          _clipRange.start.toStringAsFixed(2),
          '-i',
          _videoPath!,
          '-t',
          clipDur.toStringAsFixed(2),
          '-loop',
          '1',
          '-t',
          '3.0',
          '-i',
          freezeImgPath,
          '-i',
          bannerPngPath,
          '-i',
          sfxPath,
          '-filter_complex',
          filters.join(';'),
          '-map',
          '[vout]',
          '-map',
          '[aout]',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
        ]);
      }

      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '22',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outPath,
      ]);

      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();

      if (!ReturnCode.isSuccess(rc) || !File(outPath).existsSync()) {
        final logs = await session.getOutput();
        throw Exception(logs?.split('\n').last ?? 'Gaming render failed');
      }

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
          SnackBar(content: Text('Gaming Export Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller?.value.isPlaying ?? false;
    final gamingEffects = kStudioEffects
        .where((e) => ['none', 'vice_neon', 'miami_sunset', 'hdr_vivid', 'cinematic', 'neon_glow'].contains(e.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Vice Gaming Clipper 🎮')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Video Picker + Hype Scan Button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _videoName,
                  style: const TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isExporting || _isScanningHype) ? null : _pickGameplayVideo,
                        icon: const Icon(Icons.video_library_rounded, color: AppColors.viceOrange),
                        label: Text(_videoPath == null ? 'Select Gameplay Video' : 'Change Video'),
                      ),
                    ),
                    if (_isVideoReady) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: (_isExporting || _isScanningHype) ? null : _runHypeScan,
                        icon: _isScanningHype
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.local_fire_department_rounded, size: 18),
                        label: Text(_isScanningHype ? 'Scanning...' : 'Find Hype'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.viceOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Hype Moments Result Strip
          if (_hypeMoments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '🔥 Top Action / Hype Moments Found (Tap to Auto-Cut 30s):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _hypeMoments.length,
                itemBuilder: (ctx, i) {
                  final m = _hypeMoments[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('🔥 #${i + 1} (${formatClock(m.peakSec)}) • ${m.scorePercent}%'),
                      selected: _selectedHypeIdx == i,
                      selectedColor: AppColors.viceOrange,
                      onSelected: _isExporting ? null : (_) => _jumpToHypeMoment(i),
                    ),
                  );
                },
              ),
            ),
          ],

          // Live Preview Player with Live Color Grading
          if (_isVideoReady && _controller != null) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.viceOrange.withValues(alpha: 0.45)),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(_selectedEffect.previewMatrix),
                      child: VideoPlayer(_controller!),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _selectedEffect.accent),
                        ),
                        child: Text(
                          '${_selectedEffect.name} • ${_use60Fps ? "60 FPS" : "30 FPS"}',
                          style: TextStyle(color: _selectedEffect.accent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => isPlaying ? _controller!.pause() : _controller!.play(),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Clip Range Slider
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Start: ${formatClock(_clipRange.start)}',
                          style: const TextStyle(color: AppColors.neonCyan, fontSize: 12)),
                      Text('Clip: ${formatClock(_clipRange.end - _clipRange.start)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('End: ${formatClock(_clipRange.end)}',
                          style: const TextStyle(color: AppColors.neonPink, fontSize: 12)),
                    ],
                  ),
                  RangeSlider(
                    values: _clipRange,
                    min: 0,
                    max: _totalSec,
                    activeColor: AppColors.viceOrange,
                    onChanged: _isExporting
                        ? null
                        : (v) {
                            if (v.end - v.start < 1.0) return;
                            setState(() => _clipRange = v);
                            _controller?.seekTo(Duration(milliseconds: (v.start * 1000).round()));
                          },
                  ),
                  const Divider(color: Colors.white12),

                  // 9:16 Gaming Layout Mode
                  const Text('9:16 Gaming Layout:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Cinema Blur (HUD-Safe)'),
                        selected: _layoutMode == 'cinema_blur',
                        selectedColor: AppColors.neonPurple,
                        onSelected: (_) => setState(() => _layoutMode = 'cinema_blur'),
                      ),
                      ChoiceChip(
                        label: const Text('Action Zoom'),
                        selected: _layoutMode == 'action_zoom',
                        selectedColor: AppColors.neonPurple,
                        onSelected: (_) => setState(() => _layoutMode = 'action_zoom'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.face_retouching_natural, size: 15, color: AppColors.neonCyan),
                        label: const Text('AI Facecam Split →'),
                        onPressed: _openFacecamSplitWithCurrentVideo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Vice Color Presets
                  const Text('Gaming Color Preset:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: gamingEffects.map((fx) {
                      return ChoiceChip(
                        label: Text(fx.name),
                        selected: _selectedEffect.id == fx.id,
                        selectedColor: fx.accent.withValues(alpha: 0.45),
                        onSelected: (_) => setState(() => _selectedEffect = fx),
                      );
                    }).toList(),
                  ),
                  const Divider(color: Colors.white12, height: 22),

                  // 1-Tap Fail / Mission Clear Freeze Ending
                  const Text('1-Tap Freeze-Frame Ending (+ Dramatic SFX):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: _freezeMode == 'none',
                        selectedColor: Colors.white24,
                        onSelected: (_) => _setFreezeMode('none'),
                      ),
                      ChoiceChip(
                        label: const Text('💀 Fail Freeze'),
                        selected: _freezeMode == 'fail',
                        selectedColor: Colors.redAccent,
                        onSelected: (_) => _setFreezeMode('fail'),
                      ),
                      ChoiceChip(
                        label: const Text('🏆 Mission Clear'),
                        selected: _freezeMode == 'mission',
                        selectedColor: Colors.amber.shade700,
                        onSelected: (_) => _setFreezeMode('mission'),
                      ),
                    ],
                  ),
                  if (_freezeMode != 'none') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bannerTitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Freeze Banner Main Text',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bannerSubCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subtitle Text (Optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const Divider(color: Colors.white12, height: 22),

                  // 60 FPS Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('60 FPS Smooth Gaming Mode'),
                    subtitle: const Text('High-speed driving & action clips ke liye ultra-smooth export'),
                    value: _use60Fps,
                    activeThumbColor: AppColors.neonCyan,
                    onChanged: _isExporting ? null : (v) => setState(() => _use60Fps = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isExporting) ...[
              const LinearProgressIndicator(color: AppColors.viceOrange, backgroundColor: Colors.white12),
              const SizedBox(height: 8),
              Text(_exportStatus, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neonCyan)),
              const SizedBox(height: 12),
            ],

            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportGamingClip,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(
                _isExporting ? 'Rendering Gaming Short...' : 'Export Gaming Short (${_use60Fps ? "60" : "30"} FPS)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.viceOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 4. LIVE STREAMER SPLIT SCREEN (Offline AI Facecam Top + Gameplay Bottom)
// ============================================================================
class StreamerSplitScreen extends StatefulWidget {
  final Future<void> Function(String path) onExported;
  final String? initialVideoPath;
  final String? initialVideoName;

  const StreamerSplitScreen({
    super.key,
    required this.onExported,
    this.initialVideoPath,
    this.initialVideoName,
  });

  @override
  State<StreamerSplitScreen> createState() => _StreamerSplitScreenState();
}

class _StreamerSplitScreenState extends State<StreamerSplitScreen> {
  String? _videoPath;
  String _videoName = 'Koi stream / gameplay video select nahi hai';
  VideoPlayerController? _controller;
  bool _isVideoReady = false;
  double _totalSeconds = 1.0;
  RangeValues _trimRange = const RangeValues(0, 1);

  double _faceX = 0.66;
  double _faceY = 0.04;
  double _faceW = 0.30;
  double _faceH = 0.34;
  String _detectBadge = 'Video select karein — AI khud facecam detect karega';
  bool _isDetecting = false;

  double _topPanelRatio = 0.38;
  bool _blurFillGameplay = true;
  bool _use60Fps = false;
  bool _isExporting = false;
  String _exportStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoPath != null) {
      _loadVideoFromPath(
        widget.initialVideoPath!,
        widget.initialVideoName ?? widget.initialVideoPath!.split('/').last,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickStreamVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res == null || res.files.single.path == null) return;
    await _loadVideoFromPath(res.files.single.path!, res.files.single.name);
  }

  Future<void> _loadVideoFromPath(String path, String name) async {
    await _controller?.dispose();

    setState(() {
      _videoPath = path;
      _videoName = name;
      _isVideoReady = false;
      _controller = null;
      _detectBadge = 'Video load ho raha hai...';
    });

    final ctrl = VideoPlayerController.file(File(path));
    await ctrl.initialize();
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    final secs = ctrl.value.duration.inMilliseconds / 1000.0;
    final safeTotal = secs > 1.0 ? secs : 1.0;
    final defaultEnd = math.min(safeTotal, 60.0);

    if (!mounted) {
      await ctrl.dispose();
      return;
    }

    setState(() {
      _controller = ctrl;
      _isVideoReady = true;
      _totalSeconds = safeTotal;
      _trimRange = RangeValues(0, defaultEnd);
    });

    await _autoDetectFacecam();
  }

  Future<void> _autoDetectFacecam() async {
    if (_videoPath == null) return;
    setState(() {
      _isDetecting = true;
      _detectBadge = 'AI Facecam scan kar raha hai...';
    });

    final detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast, minFaceSize: 0.04),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final sampleFractions = [0.15, 0.45, 0.75];
      Rect? bestFace;
      int imgW = 640;
      int imgH = 360;

      for (int i = 0; i < sampleFractions.length; i++) {
        final double sampleSec = (_totalSeconds * sampleFractions[i]).clamp(0.1, math.max(0.2, _totalSeconds - 0.3));
        final String framePath = '${tempDir.path}/vcs_face_scan_$i.jpg';
        final f = File(framePath);
        if (f.existsSync()) f.deleteSync();

        final session = await FFmpegKit.executeWithArguments([
          '-y',
          '-ss',
          sampleSec.toStringAsFixed(2),
          '-i',
          _videoPath!,
          '-vframes',
          '1',
          '-vf',
          'scale=640:-2',
          '-q:v',
          '4',
          framePath,
        ]);
        final rc = await session.getReturnCode();
        if (!ReturnCode.isSuccess(rc) || !File(framePath).existsSync()) continue;

        final bytes = await File(framePath).readAsBytes();
        final decoded = await decodeImageFromList(bytes);
        imgW = decoded.width;
        imgH = decoded.height;
        decoded.dispose();

        final inputImage = InputImage.fromFilePath(framePath);
        final faces = await detector.processImage(inputImage);
        if (faces.isNotEmpty) {
          faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height));
          bestFace = faces.first.boundingBox;
          break;
        }
      }

      if (bestFace != null && imgW > 0 && imgH > 0) {
        final double cx = bestFace.center.dx / imgW;
        final double cy = bestFace.center.dy / imgH;
        final double fw = bestFace.width / imgW;
        final double fh = bestFace.height / imgH;

        final double boxW = (fw * 2.9).clamp(0.24, 0.48);
        final double boxH = (fh * 2.6).clamp(0.24, 0.52);
        final double boxX = (cx - boxW / 2.0).clamp(0.0, 0.995 - boxW);
        final double boxY = (cy - boxH / 2.0).clamp(0.0, 0.995 - boxH);

        String posLabel = 'Center';
        if (cx < 0.45 && cy < 0.5) {
          posLabel = 'Top-Left';
        } else if (cx >= 0.55 && cy < 0.5) {
          posLabel = 'Top-Right';
        } else if (cx < 0.45 && cy >= 0.5) {
          posLabel = 'Bottom-Left';
        } else if (cx >= 0.55 && cy >= 0.5) {
          posLabel = 'Bottom-Right';
        }

        if (mounted) {
          setState(() {
            _faceW = boxW;
            _faceH = boxH;
            _faceX = boxX;
            _faceY = boxY;
            _detectBadge = 'AI Facecam Detected: $posLabel ✅ (Box drag karke adjust kar sakte ho)';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _applyCornerPreset('TR');
            _detectBadge = 'Auto face nahi mila — Cyan Box drag karo ya corner button chuno';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _applyCornerPreset('TR');
          _detectBadge = 'Manual Mode ready — Cyan Box facecam par set karo';
        });
      }
    } finally {
      await detector.close();
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  void _applyCornerPreset(String code) {
    setState(() {
      _faceW = _faceW.clamp(0.22, 0.48);
      _faceH = _faceH.clamp(0.24, 0.52);
      if (code == 'TL') {
        _faceX = 0.02;
        _faceY = 0.03;
      } else if (code == 'TR') {
        _faceX = 0.98 - _faceW;
        _faceY = 0.03;
      } else if (code == 'BL') {
        _faceX = 0.02;
        _faceY = 0.97 - _faceH;
      } else if (code == 'BR') {
        _faceX = 0.98 - _faceW;
        _faceY = 0.97 - _faceH;
      }
    });
  }

  Future<void> _exportStreamerSplit() async {
    if (_videoPath == null) return;
    await _controller?.pause();

    setState(() {
      _isExporting = true;
      _exportStatus = '9:16 Facecam + Gameplay render ho raha hai...';
    });

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      final probe = await probeVideoInfo(_videoPath!);
      final double clipDur = math.max(1.0, _trimRange.end - _trimRange.start);
      final int outFps = _use60Fps ? 60 : 30;

      final int topH = ((1280 * _topPanelRatio) / 2).round() * 2;
      final int botH = 1280 - topH;

      final double safeW = _faceW.clamp(0.15, 0.90);
      final double safeH = _faceH.clamp(0.15, 0.90);
      final double safeX = _faceX.clamp(0.0, 0.995 - safeW);
      final double safeY = _faceY.clamp(0.0, 0.995 - safeH);

      final String topFilter =
          '[face_in]crop=trunc(iw*${safeW.toStringAsFixed(4)}):trunc(ih*${safeH.toStringAsFixed(4)}):'
          'trunc(iw*${safeX.toStringAsFixed(4)}):trunc(ih*${safeY.toStringAsFixed(4)}),'
          'scale=720:$topH:force_original_aspect_ratio=increase,crop=720:$topH,setsar=1[top]';

      final String botFilter = _blurFillGameplay
          ? '[game_in]split=2[gbg][gfg];'
              '[gbg]scale=720:$botH:force_original_aspect_ratio=increase,crop=720:$botH,gblur=sigma=18[gbgb];'
              '[gfg]scale=720:$botH:force_original_aspect_ratio=decrease[gfgs];'
              '[gbgb][gfgs]overlay=(W-w)/2:(H-h)/2,setsar=1[bot]'
          : '[game_in]scale=720:$botH:force_original_aspect_ratio=increase,crop=720:$botH,setsar=1[bot]';

      final String filterComplex =
          '[0:v]split=2[face_in][game_in];'
          '$topFilter;'
          '$botFilter;'
          '[top][bot]vstack=inputs=2,fps=$outFps,format=yuv420p[vout]';

      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/vcs_streamer_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final List<String> args = [
        '-y',
        '-ss',
        _trimRange.start.toStringAsFixed(2),
        '-i',
        _videoPath!,
        '-t',
        clipDur.toStringAsFixed(2),
        '-filter_complex',
        filterComplex,
        '-map',
        '[vout]',
      ];

      if (probe.hasAudio) {
        args.addAll(['-map', '0:a', '-c:a', 'aac', '-b:a', '128k']);
      } else {
        args.add('-an');
      }

      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '23',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outPath,
      ]);

      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();

      if (!ReturnCode.isSuccess(rc) || !File(outPath).existsSync()) {
        final logs = await session.getOutput();
        throw Exception(logs?.split('\n').last ?? 'Streamer render failed');
      }

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
          SnackBar(content: Text('Streamer Split Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streamer Split (AI Facecam)'),
        actions: [
          if (_isVideoReady)
            TextButton.icon(
              onPressed: (_isDetecting || _isExporting) ? null : _autoDetectFacecam,
              icon: const Icon(Icons.face_retouching_natural, color: AppColors.neonCyan, size: 18),
              label: const Text('AI Scan', style: TextStyle(color: AppColors.neonCyan)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _videoName,
                  style: const TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(_detectBadge, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: (_isExporting || _isDetecting) ? null : _pickStreamVideo,
                  icon: const Icon(Icons.video_library_rounded, color: AppColors.neonCyan),
                  label: Text(_videoPath == null ? 'Select Live Stream / Gameplay Video' : 'Change Video'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_isVideoReady && _controller != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    final maxW = box.maxWidth;
                    final maxH = box.maxHeight;
                    return Stack(
                      children: [
                        Positioned.fill(child: VideoPlayer(_controller!)),
                        Positioned(
                          left: _faceX * maxW,
                          top: _faceY * maxH,
                          width: _faceW * maxW,
                          height: _faceH * maxH,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _faceX = (_faceX + details.delta.dx / maxW).clamp(0.0, 0.995 - _faceW);
                                _faceY = (_faceY + details.delta.dy / maxH).clamp(0.0, 0.995 - _faceH);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.neonCyan.withValues(alpha: 0.18),
                                border: Border.all(color: AppColors.neonCyan, width: 2.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Text(
                                    'FACECAM (TOP)',
                                    style: TextStyle(
                                      backgroundColor: Colors.black87,
                                      color: AppColors.neonCyan,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: GestureDetector(
                            onTap: () => isPlaying ? _controller!.pause() : _controller!.play(),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_isDetecting)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: AppColors.neonCyan),
                                    SizedBox(height: 8),
                                    Text('AI Detecting Facecam...', style: TextStyle(color: AppColors.neonCyan)),
                                  ],
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Facecam Position (Ya Box ko ungli se drag karo):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.auto_awesome, size: 15, color: AppColors.neonCyan),
                        label: const Text('Auto AI'),
                        onPressed: _isDetecting ? null : _autoDetectFacecam,
                      ),
                      ActionChip(label: const Text('Top-Left'), onPressed: () => _applyCornerPreset('TL')),
                      ActionChip(label: const Text('Top-Right'), onPressed: () => _applyCornerPreset('TR')),
                      ActionChip(label: const Text('Bottom-Left'), onPressed: () => _applyCornerPreset('BL')),
                      ActionChip(label: const Text('Bottom-Right'), onPressed: () => _applyCornerPreset('BR')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Box Size:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      Expanded(
                        child: Slider(
                          value: _faceW,
                          min: 0.18,
                          max: 0.55,
                          activeColor: AppColors.neonCyan,
                          onChanged: (v) {
                            setState(() {
                              _faceW = v;
                              _faceH = (v * 1.15).clamp(0.20, 0.65);
                              _faceX = _faceX.clamp(0.0, 0.995 - _faceW);
                              _faceY = _faceY.clamp(0.0, 0.995 - _faceH);
                            });
                          },
                        ),
                      ),
                      Text('${(_faceW * 100).round()}%'),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  const Text('Clip Range (Highlight Cut):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Start: ${formatClock(_trimRange.start)}',
                          style: const TextStyle(color: AppColors.neonCyan, fontSize: 12)),
                      Text('Length: ${formatClock(_trimRange.end - _trimRange.start)}',
                          style: const TextStyle(fontSize: 12)),
                      Text('End: ${formatClock(_trimRange.end)}',
                          style: const TextStyle(color: AppColors.neonPink, fontSize: 12)),
                    ],
                  ),
                  RangeSlider(
                    values: _trimRange,
                    min: 0,
                    max: _totalSeconds,
                    activeColor: AppColors.neonPurple,
                    onChanged: (vals) {
                      if (vals.end - vals.start < 1.0) return;
                      setState(() => _trimRange = vals);
                      _controller?.seekTo(Duration(milliseconds: (vals.start * 1000).round()));
                    },
                  ),
                  const Divider(color: Colors.white12),
                  const Text('Upar Facecam ki Height:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('32% Compact'),
                        selected: _topPanelRatio == 0.32,
                        selectedColor: AppColors.neonPurple,
                        onSelected: (_) => setState(() => _topPanelRatio = 0.32),
                      ),
                      ChoiceChip(
                        label: const Text('38% Pro'),
                        selected: _topPanelRatio == 0.38,
                        selectedColor: AppColors.neonPurple,
                        onSelected: (_) => setState(() => _topPanelRatio = 0.38),
                      ),
                      ChoiceChip(
                        label: const Text('45% Half'),
                        selected: _topPanelRatio == 0.45,
                        selectedColor: AppColors.neonPurple,
                        onSelected: (_) => setState(() => _topPanelRatio = 0.45),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Full Gameplay HUD + Blur Frame'),
                    subtitle: const Text('ON = Poora gameplay dikhega • OFF = Center Zoom'),
                    value: _blurFillGameplay,
                    activeThumbColor: AppColors.neonCyan,
                    onChanged: (v) => setState(() => _blurFillGameplay = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('60 FPS Smooth Gaming Mode'),
                    value: _use60Fps,
                    activeThumbColor: AppColors.neonCyan,
                    onChanged: (v) => setState(() => _use60Fps = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isExporting) ...[
              const LinearProgressIndicator(color: AppColors.neonCyan, backgroundColor: Colors.white12),
              const SizedBox(height: 8),
              Text(_exportStatus, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neonCyan)),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: (_isExporting || _isDetecting) ? null : _exportStreamerSplit,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(
                _isExporting ? 'Rendering Split-Screen...' : 'Export 9:16 Streamer Short',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 5. AUTO-SPLIT SHORTS SCREEN (Live Video Preview + 9:16 Crop Guide + Part Chips)
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
  VideoPlayerController? _controller;
  bool _isVideoReady = false;
  double _totalSec = 0.0;

  int _chunkSec = 30;
  bool _crop9x16 = true;
  List<List<double>> _segments = [];
  int _selectedPartIdx = 0;

  bool _isProcessing = false;
  int _exportingPartIdx = -1;
  String _status = '';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _rebuildSegments() {
    if (_totalSec <= 0) {
      _segments = [];
      return;
    }
    final list = <List<double>>[];
    double start = 0.0;
    while (start < _totalSec) {
      double end = start + _chunkSec;
      if (end > _totalSec) end = _totalSec;
      if ((end - start) < 2.0 && list.isNotEmpty) break;
      list.add([start, end]);
      start = end;
    }
    _segments = list;
    _selectedPartIdx = 0;
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    if (res == null || res.files.single.path == null) return;

    await _controller?.dispose();
    final path = res.files.single.path!;
    final name = res.files.single.name;

    setState(() {
      _videoPath = path;
      _videoName = name;
      _isVideoReady = false;
      _controller = null;
    });

    final ctrl = VideoPlayerController.file(File(path));
    await ctrl.initialize();
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    final totalSec = ctrl.value.duration.inMilliseconds / 1000.0;
    if (!mounted) {
      await ctrl.dispose();
      return;
    }

    setState(() {
      _controller = ctrl;
      _isVideoReady = true;
      _totalSec = totalSec > 0 ? totalSec : 1.0;
      _rebuildSegments();
    });
  }

  Future<void> _previewPart(int index) async {
    if (index < 0 || index >= _segments.length || _controller == null) return;
    setState(() => _selectedPartIdx = index);
    await _controller!.seekTo(Duration(milliseconds: (_segments[index][0] * 1000).round()));
    await _controller!.play();
  }

  Future<void> _runSplit() async {
    if (_videoPath == null || _segments.isEmpty) return;
    await _controller?.pause();

    setState(() {
      _isProcessing = true;
      _exportingPartIdx = 0;
      _status = 'Video check ho raha hai...';
    });

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      final probe = await probeVideoInfo(_videoPath!);
      final tempDir = await getTemporaryDirectory();
      int saved = 0;

      for (int i = 0; i < _segments.length; i++) {
        if (!mounted) return;
        final double st = _segments[i][0];
        final double dur = math.max(0.5, _segments[i][1] - st);

        setState(() {
          _exportingPartIdx = i;
          _selectedPartIdx = i;
          _status =
              'Part ${i + 1} / ${_segments.length} (${formatClock(st)} - ${formatClock(_segments[i][1])}) export ho raha hai...';
        });

        await _controller?.seekTo(Duration(milliseconds: (st * 1000).round()));

        final outPath = '${tempDir.path}/vcs_part${i + 1}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final List<String> vf = [];
        if (_crop9x16) {
          vf.add(r'crop=min(iw\,ih*9/16):min(ih\,iw*16/9)');
          vf.add(r'scale=if(gte(iw\,ih)\,-2\,min(iw\,720)):if(gte(iw\,ih)\,min(ih\,720)\,-2)');
        }
        vf.add('scale=trunc(iw/2)*2:trunc(ih/2)*2');

        final List<String> args = [
          '-y',
          '-ss',
          st.toStringAsFixed(2),
          '-i',
          _videoPath!,
          '-t',
          dur.toStringAsFixed(2),
          '-vf',
          vf.join(','),
        ];

        if (probe.hasAudio) {
          args.addAll(['-c:a', 'aac', '-b:a', '128k']);
        } else {
          args.add('-an');
        }

        args.addAll([
          '-c:v',
          'libx264',
          '-preset',
          'ultrafast',
          '-crf',
          '23',
          '-pix_fmt',
          'yuv420p',
          '-movflags',
          '+faststart',
          outPath,
        ]);

        final session = await FFmpegKit.executeWithArguments(args);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc) && File(outPath).existsSync()) {
          await Gal.putVideo(outPath, album: 'Viral Clip Studio');
          await widget.onExported(outPath);
          saved++;
        }
      }

      if (!mounted) return;
      if (saved > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$saved / ${_segments.length} parts Gallery -> Viral Clip Studio mein save ho gaye! ✅'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        throw Exception('Koi bhi part export nahi ho paya');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-Split Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _exportingPartIdx = -1;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller?.value.isPlaying ?? false;
    final posSec = (_controller?.value.position.inMilliseconds ?? 0) / 1000.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Split Shorts (Live Preview)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isVideoReady && _controller != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    final maxW = box.maxWidth;
                    final maxH = box.maxHeight;
                    final double cropW = math.min(maxW, maxH * (9.0 / 16.0));
                    final double cropH = math.min(maxH, maxW * (16.0 / 9.0));
                    final double sidePad = (maxW - cropW) / 2.0;
                    final double topPad = (maxH - cropH) / 2.0;

                    return Stack(
                      children: [
                        Positioned.fill(child: VideoPlayer(_controller!)),
                        if (_crop9x16) ...[
                          if (sidePad > 1) ...[
                            Positioned(
                                left: 0, top: 0, bottom: 0, width: sidePad, child: Container(color: Colors.black54)),
                            Positioned(
                                right: 0, top: 0, bottom: 0, width: sidePad, child: Container(color: Colors.black54)),
                          ],
                          if (topPad > 1) ...[
                            Positioned(
                                left: 0, right: 0, top: 0, height: topPad, child: Container(color: Colors.black54)),
                            Positioned(
                                left: 0, right: 0, bottom: 0, height: topPad, child: Container(color: Colors.black54)),
                          ],
                          Positioned(
                            left: sidePad,
                            top: topPad,
                            width: cropW,
                            height: cropH,
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: AppColors.neonCyan, width: 2)),
                              child: const Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    '9:16 CLIP AREA',
                                    style: TextStyle(
                                      backgroundColor: Colors.black87,
                                      color: AppColors.neonCyan,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                            child: Text('${formatClock(posSec)} / ${formatClock(_totalSec)}',
                                style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: GestureDetector(
                            onTap: () => isPlaying ? _controller!.pause() : _controller!.play(),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.black54,
                              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_segments.isNotEmpty) ...[
              Text(
                'Total ${_segments.length} Parts Banenge (Tap karke preview dekho):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _segments.length,
                  itemBuilder: (ctx, i) {
                    final isExp = _exportingPartIdx == i;
                    final isSel = _selectedPartIdx == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Part ${i + 1} (${formatClock(_segments[i][0])})',
                            style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: isExp ? Colors.green : AppColors.neonPurple,
                        onSelected: _isProcessing ? null : (_) => _previewPart(i),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Long Video -> Multiple Shorts Parts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_videoName,
                    style: const TextStyle(color: AppColors.neonCyan, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_rounded),
                  label: Text(_videoPath == null ? 'Select Long Video' : 'Change Video'),
                ),
                const SizedBox(height: 16),
                const Text('Har Part ki Length:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [15, 30, 45, 60].map((sec) {
                    return ChoiceChip(
                      label: Text('${sec}s'),
                      selected: _chunkSec == sec,
                      selectedColor: AppColors.neonPurple,
                      onSelected: _isProcessing
                          ? null
                          : (_) => setState(() {
                                _chunkSec = sec;
                                _rebuildSegments();
                              }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('9:16 Vertical Shorts Crop'),
                  subtitle: const Text('Cyan box wala area Shorts mein crop hoga'),
                  value: _crop9x16,
                  activeThumbColor: AppColors.neonCyan,
                  onChanged: _isProcessing ? null : (v) => setState(() => _crop9x16 = v),
                ),
                const SizedBox(height: 12),
                if (_isProcessing) ...[
                  const LinearProgressIndicator(color: AppColors.neonCyan, backgroundColor: Colors.white12),
                  const SizedBox(height: 8),
                  Text(_status,
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neonCyan, fontSize: 12)),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: (_isProcessing || _videoPath == null || _segments.isEmpty) ? null : _runSplit,
                  icon: const Icon(Icons.content_cut_rounded),
                  label: Text(
                    _isProcessing
                        ? 'Exporting Parts...'
                        : 'Auto-Split & Save ${_segments.isEmpty ? "All" : _segments.length} Parts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
// 6. CRASH-PROOF FFMPEG MULTI-CLIP MERGER SCREEN
// ============================================================================
class MultiClipMergerScreen extends StatefulWidget {
  final Future<void> Function(String path) onExported;

  const MultiClipMergerScreen({super.key, required this.onExported});

  @override
  State<MultiClipMergerScreen> createState() => _MultiClipMergerScreenState();
}

class _MultiClipMergerScreenState extends State<MultiClipMergerScreen> {
  final List<String> _paths = [];
  final List<String> _names = [];
  String _outputAspect = '9:16';
  bool _isProcessing = false;
  String _status = '';

  Future<void> _pickVideos() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (res == null) return;
    setState(() {
      for (final f in res.files) {
        if (f.path != null) {
          _paths.add(f.path!);
          _names.add(f.name);
        }
      }
    });
  }

  Future<void> _mergeWithFfmpeg() async {
    if (_paths.length < 2) return;
    setState(() {
      _isProcessing = true;
      _status = 'Videos analyze ho rahe hain...';
    });

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      final probes = <VideoProbeResult>[];
      bool anyHasAudio = false;
      for (int i = 0; i < _paths.length; i++) {
        if (mounted) setState(() => _status = 'Checking clip ${i + 1} / ${_paths.length}...');
        final info = await probeVideoInfo(_paths[i]);
        probes.add(info);
        if (info.hasAudio) anyHasAudio = true;
      }

      final int w = _outputAspect == '9:16' ? 720 : (_outputAspect == '1:1' ? 720 : 1280);
      final int h = _outputAspect == '9:16' ? 1280 : (_outputAspect == '1:1' ? 720 : 720);

      final List<String> args = ['-y'];
      for (final p in _paths) {
        args.addAll(['-i', p]);
      }

      final List<String> filters = [];
      final StringBuffer concatInputs = StringBuffer();

      for (int i = 0; i < _paths.length; i++) {
        filters.add(
          '[$i:v]scale=$w:$h:force_original_aspect_ratio=decrease,'
          'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=30,setpts=PTS-STARTPTS,format=yuv420p[v$i]',
        );
        if (anyHasAudio) {
          if (probes[i].hasAudio) {
            filters.add(
              '[$i:a]aformat=sample_rates=44100:channel_layouts=stereo,aresample=async=1,asetpts=PTS-STARTPTS[a$i]',
            );
          } else {
            filters.add(
              'anullsrc=channel_layout=stereo:sample_rate=44100,atrim=duration=${probes[i].durationSec.toStringAsFixed(2)},asetpts=PTS-STARTPTS[a$i]',
            );
          }
          concatInputs.write('[v$i][a$i]');
        } else {
          concatInputs.write('[v$i]');
        }
      }

      if (anyHasAudio) {
        filters.add('${concatInputs}concat=n=${_paths.length}:v=1:a=1[vout][aout]');
      } else {
        filters.add('${concatInputs}concat=n=${_paths.length}:v=1:a=0[vout]');
      }

      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/vcs_merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

      args.addAll(['-filter_complex', filters.join(';'), '-map', '[vout]']);
      if (anyHasAudio) {
        args.addAll(['-map', '[aout]', '-c:a', 'aac', '-b:a', '128k']);
      } else {
        args.add('-an');
      }
      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '23',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outPath,
      ]);

      if (mounted) setState(() => _status = '${_paths.length} clips safely merge ho rahe hain...');

      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();

      if (!ReturnCode.isSuccess(rc) || !File(outPath).existsSync()) {
        final logs = await session.getOutput();
        throw Exception(logs?.split('\n').last ?? 'Merge failed');
      }

      await Gal.putVideo(outPath, album: 'Viral Clip Studio');
      await widget.onExported(outPath);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ExportSuccessScreen(outputPath: outPath, savedToGallery: true)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge error: $e'), backgroundColor: Colors.redAccent),
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
      appBar: AppBar(title: const Text('Multi-Clip Merger (Crash-Proof)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Selected Clips (${_paths.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (_paths.isNotEmpty)
                      TextButton(
                        onPressed: _isProcessing
                            ? null
                            : () => setState(() {
                                  _paths.clear();
                                  _names.clear();
                                }),
                        child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
                const Text('Kisi bhi resolution ya FPS ke videos bina crash ke ek saath jodein.',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 12),
                if (_names.isNotEmpty)
                  ..._names.asMap().entries.map(
                        (e) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${e.key + 1}. ${e.value}',
                                    style: const TextStyle(color: AppColors.neonCyan, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                                onPressed: _isProcessing
                                    ? null
                                    : () => setState(() {
                                          _paths.removeAt(e.key);
                                          _names.removeAt(e.key);
                                        }),
                              ),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickVideos,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(_paths.isEmpty ? 'Select 2 or More Videos' : 'Add More Videos'),
                ),
                const SizedBox(height: 14),
                const Text('Output Video Size:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['9:16', '16:9', '1:1'].map((r) {
                    return ChoiceChip(
                      label: Text(r == '9:16' ? '9:16 Shorts' : (r == '16:9' ? '16:9 YouTube' : '1:1 Square')),
                      selected: _outputAspect == r,
                      selectedColor: AppColors.neonPurple,
                      onSelected: _isProcessing ? null : (_) => setState(() => _outputAspect = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (_isProcessing) ...[
                  const LinearProgressIndicator(color: AppColors.neonPink, backgroundColor: Colors.white12),
                  const SizedBox(height: 8),
                  Text(_status,
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neonCyan, fontSize: 12)),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: (_isProcessing || _paths.length < 2) ? null : _mergeWithFfmpeg,
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

// ============================================================================
// 7. EFFECTS GALLERY SCREEN (14 Effects incl. Gaming Category)
// ============================================================================
class EffectsGalleryScreen extends StatefulWidget {
  final ValueChanged<String> onApplyEffect;

  const EffectsGalleryScreen({super.key, required this.onApplyEffect});

  @override
  State<EffectsGalleryScreen> createState() => _EffectsGalleryScreenState();
}

class _EffectsGalleryScreenState extends State<EffectsGalleryScreen> {
  String _selectedCat = 'All';

  @override
  Widget build(BuildContext context) {
    final cats = ['All', 'Gaming', 'Trending', 'Cinematic', 'Retro', 'Basic'];
    final items = kStudioEffects.where((e) {
      if (e.id == 'none') return false;
      if (_selectedCat == 'All') return true;
      return e.category == _selectedCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Premium Effects Studio (14)')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: cats.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _selectedCat == c,
                    selectedColor: AppColors.neonPurple,
                    onSelected: (_) => setState(() => _selectedCat = c),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final fx = items[idx];
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onApplyEffect(fx.id);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [fx.accent.withValues(alpha: 0.35), AppColors.surface],
                      ),
                      border: Border.all(color: fx.accent.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(fx.icon, color: fx.accent, size: 26),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(fx.category, style: const TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fx.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            const Text('Tap to apply on video →',
                                style: TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
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
// 8. BUILT-IN MUSIC PACKS LIBRARY
// ============================================================================
class SelectedMusicResult {
  final String path;
  final String title;
  const SelectedMusicResult({required this.path, required this.title});
}

class StudioMusicLibraryScreen extends StatefulWidget {
  final bool pickerMode;

  const StudioMusicLibraryScreen({super.key, required this.pickerMode});

  @override
  State<StudioMusicLibraryScreen> createState() => _StudioMusicLibraryScreenState();
}

class _StudioMusicLibraryScreenState extends State<StudioMusicLibraryScreen> {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, bool> _downloaded = {};
  final Set<String> _downloading = {};
  String? _playingId;
  bool _downloadingAll = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    for (final t in kBuiltInMusicTracks) {
      final ok = await StudioMusicPackManager.isDownloaded(t);
      _downloaded[t.id] = ok;
    }
    if (mounted) setState(() {});
  }

  Future<String> _downloadOne(BuiltInMusicTrack track) async {
    setState(() => _downloading.add(track.id));
    final path = await StudioMusicPackManager.ensureDownloaded(track);
    if (mounted) {
      setState(() {
        _downloading.remove(track.id);
        _downloaded[track.id] = true;
      });
    }
    return path;
  }

  Future<void> _downloadAllPacks() async {
    setState(() => _downloadingAll = true);
    for (final t in kBuiltInMusicTracks) {
      await _downloadOne(t);
    }
    if (mounted) {
      setState(() => _downloadingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sabhi 8 Studio Music Packs app mein ready ho gaye! 🎵'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _togglePlay(BuiltInMusicTrack track) async {
    if (_playingId == track.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    final path = await _downloadOne(track);
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    if (mounted) setState(() => _playingId = track.id);
  }

  Future<void> _pickCustomAudio() async {
    await _player.stop();
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.path != null && mounted) {
      Navigator.pop(
        context,
        SelectedMusicResult(path: res.files.single.path!, title: res.files.single.name),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyCount = _downloaded.values.where((v) => v).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickerMode ? 'Select Background Music' : 'Studio Music Packs'),
        actions: [
          if (readyCount < kBuiltInMusicTracks.length)
            TextButton.icon(
              onPressed: _downloadingAll ? null : _downloadAllPacks,
              icon: _downloadingAll
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, color: AppColors.neonCyan, size: 18),
              label: const Text('Get All', style: TextStyle(color: AppColors.neonCyan)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.pickerMode) ...[
            OutlinedButton.icon(
              onPressed: _pickCustomAudio,
              icon: const Icon(Icons.library_music_rounded, color: AppColors.neonPink),
              label: const Text('Import Custom MP3 / Song from Phone'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.neonPink),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Built-In Copyright-Free Studio Tracks (8)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ...kBuiltInMusicTracks.map((track) {
            final isReady = _downloaded[track.id] == true;
            final isBusy = _downloading.contains(track.id);
            final isPlaying = _playingId == track.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isPlaying ? AppColors.neonCyan : Colors.white10),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: isBusy ? null : () => _togglePlay(track),
                    icon: isBusy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            color: track.color,
                            size: 36,
                          ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '${track.mood}  •  ${track.bpm} BPM  •  ${isReady ? "Ready Offline ✓" : "Tap to Download"}',
                          style: TextStyle(fontSize: 11, color: isReady ? Colors.greenAccent : Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  if (widget.pickerMode)
                    ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              await _player.stop();
                              final path = await _downloadOne(track);
                              if (!context.mounted) return;
                              Navigator.pop(context, SelectedMusicResult(path: path, title: track.title));
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Use', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    IconButton(
                      onPressed: isReady || isBusy ? null : () => _downloadOne(track),
                      icon: Icon(
                        isReady ? Icons.check_circle_rounded : Icons.download_for_offline_rounded,
                        color: isReady ? Colors.greenAccent : AppColors.neonCyan,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. ONE-CLICK PHOTO-TO-VIDEO STUDIO
// ============================================================================
class PhotoToVideoStudioScreen extends StatefulWidget {
  final String? initialTransitionId;
  final Future<void> Function(String path) onExported;

  const PhotoToVideoStudioScreen({
    super.key,
    this.initialTransitionId,
    required this.onExported,
  });

  @override
  State<PhotoToVideoStudioScreen> createState() => _PhotoToVideoStudioScreenState();
}

class _PhotoToVideoStudioScreenState extends State<PhotoToVideoStudioScreen> {
  List<String> _photoPaths = [];
  late TransitionPreset _selectedTransition;
  VideoEffectPreset _selectedEffect = kStudioEffects.first;
  double _photoDurationSec = 3.0;
  String _aspectRatio = '9:16';
  bool _blurBackgroundFrame = true;
  String? _musicPath;
  String _musicTitle = 'Auto: Lo-Fi Chill (Tap to change)';
  double _musicVolume = 0.85;
  bool _useMusic = true;
  bool _isRendering = false;
  String _renderStatus = '';

  @override
  void initState() {
    super.initState();
    _selectedTransition = kStudioTransitions.firstWhere(
      (t) => t.id == widget.initialTransitionId,
      orElse: () => kStudioTransitions.first,
    );
  }

  Future<void> _pickPhotos() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res == null) return;
    final picked = res.files.where((f) => f.path != null).map((f) => f.path!).toList();
    if (picked.isNotEmpty) {
      setState(() => _photoPaths = [..._photoPaths, ...picked].take(15).toList());
    }
  }

  Future<void> _pickMusic() async {
    final res = await Navigator.of(context).push<SelectedMusicResult>(
      MaterialPageRoute(builder: (_) => const StudioMusicLibraryScreen(pickerMode: true)),
    );
    if (res != null) {
      setState(() {
        _musicPath = res.path;
        _musicTitle = res.title;
        _useMusic = true;
      });
    }
  }

  Future<void> _generatePhotoVideo() async {
    if (_photoPaths.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transition video banane ke liye kam se kam 2 photos select karein!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isRendering = true;
      _renderStatus = 'Music & frames prepare ho rahe hain...';
    });

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      String? activeMusicPath = _musicPath;
      if (_useMusic && activeMusicPath == null) {
        activeMusicPath = await StudioMusicPackManager.ensureDownloaded(kBuiltInMusicTracks.first);
      }

      final int w = _aspectRatio == '9:16' ? 720 : (_aspectRatio == '1:1' ? 720 : 1280);
      final int h = _aspectRatio == '9:16' ? 1280 : (_aspectRatio == '1:1' ? 720 : 720);
      const double transDur = 0.7;
      final double dur = _photoDurationSec;
      final int n = _photoPaths.length;
      final double totalDuration = n * dur - (n - 1) * transDur;

      final List<String> args = ['-y'];
      for (final p in _photoPaths) {
        args.addAll(['-loop', '1', '-t', dur.toStringAsFixed(2), '-i', p]);
      }
      if (_useMusic && activeMusicPath != null) {
        args.addAll(['-stream_loop', '-1', '-i', activeMusicPath]);
      }

      final List<String> filters = [];
      for (int i = 0; i < n; i++) {
        if (_blurBackgroundFrame) {
          filters.add(
            '[$i:v]split=2[bg$i][fg$i];'
            '[bg$i]scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,gblur=sigma=20[bgb$i];'
            '[fg$i]scale=$w:$h:force_original_aspect_ratio=decrease[fgs$i];'
            '[bgb$i][fgs$i]overlay=(W-w)/2:(H-h)/2,setsar=1,fps=30,format=yuv420p[v$i]',
          );
        } else {
          filters.add(
            '[$i:v]scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1,fps=30,format=yuv420p[v$i]',
          );
        }
      }

      final tList = _selectedTransition.xfadeNames;
      for (int k = 1; k < n; k++) {
        final String prevLabel = k == 1 ? 'v0' : 'xf${k - 1}';
        final String outLabel = k == n - 1 ? 'vbase' : 'xf$k';
        final double offset = k * (dur - transDur);
        final String xfadeType = tList[(k - 1) % tList.length];
        filters.add(
          '[$prevLabel][v$k]xfade=transition=$xfadeType:duration=${transDur.toStringAsFixed(2)}:offset=${offset.toStringAsFixed(2)}[$outLabel]',
        );
      }

      if (_selectedEffect.ffmpegFilter.isNotEmpty) {
        filters.add('[vbase]${_selectedEffect.ffmpegFilter},format=yuv420p[vout]');
      } else {
        filters.add('[vbase]format=yuv420p[vout]');
      }

      if (_useMusic && activeMusicPath != null) {
        final double fadeOutStart = math.max(0.0, totalDuration - 1.4);
        filters.add(
          '[$n:a]volume=${_musicVolume.toStringAsFixed(2)},afade=t=in:st=0:d=0.6,afade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=1.4[aout]',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/vcs_photo_reel_${DateTime.now().millisecondsSinceEpoch}.mp4';

      args.addAll(['-filter_complex', filters.join(';'), '-map', '[vout]']);
      if (_useMusic && activeMusicPath != null) {
        args.addAll(['-map', '[aout]', '-t', totalDuration.toStringAsFixed(2), '-c:a', 'aac', '-b:a', '128k']);
      } else {
        args.add('-an');
      }
      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '23',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outPath,
      ]);

      if (mounted) {
        setState(() => _renderStatus = 'Rendering $n photos with ${_selectedTransition.name}...');
      }

      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();

      if (!ReturnCode.isSuccess(rc) || !File(outPath).existsSync()) {
        final logs = await session.getOutput();
        throw Exception('Render failed: ${logs?.split("\n").last ?? "FFmpeg error"}');
      }

      await Gal.putVideo(outPath, album: 'Viral Clip Studio');
      await widget.onExported(outPath);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ExportSuccessScreen(outputPath: outPath, savedToGallery: true)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo Video Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRendering = false;
          _renderStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1-Click Photo-to-Video')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Photos Selected (${_photoPaths.length} / 15)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (_photoPaths.isNotEmpty)
                      TextButton(
                        onPressed: _isRendering ? null : () => setState(() => _photoPaths.clear()),
                        child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
                if (_photoPaths.isNotEmpty)
                  SizedBox(
                    height: 86,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoPaths.length,
                      itemBuilder: (ctx, i) {
                        return Stack(
                          children: [
                            Container(
                              width: 72,
                              margin: const EdgeInsets.only(right: 8, top: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(File(_photoPaths[i]), fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 4,
                              top: 0,
                              child: GestureDetector(
                                onTap: _isRendering ? null : () => setState(() => _photoPaths.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.redAccent,
                                  child: Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isRendering ? null : _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.neonCyan),
                  label: Text(_photoPaths.isEmpty ? 'Select 2+ Photos from Gallery' : 'Add More Photos'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Premium Transitions (1-Click):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kStudioTransitions.length,
              itemBuilder: (ctx, idx) {
                final tr = kStudioTransitions[idx];
                final active = _selectedTransition.id == tr.id;
                return GestureDetector(
                  onTap: _isRendering ? null : () => setState(() => _selectedTransition = tr),
                  child: Container(
                    width: 112,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active ? tr.color.withValues(alpha: 0.25) : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? tr.color : Colors.white10, width: active ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tr.icon, color: tr.color, size: 24),
                        const SizedBox(height: 6),
                        Text(tr.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(tr.tag, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('Color Effect Overlay:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kStudioEffects.length,
              itemBuilder: (ctx, idx) {
                final fx = kStudioEffects[idx];
                final active = _selectedEffect.id == fx.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(fx.name),
                    selected: active,
                    selectedColor: fx.accent.withValues(alpha: 0.45),
                    onSelected: _isRendering ? null : (_) => setState(() => _selectedEffect = fx),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Format & Timing:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['9:16', '1:1', '16:9'].map((r) {
                    return ChoiceChip(
                      label: Text(r == '9:16' ? '9:16 Reels' : r),
                      selected: _aspectRatio == r,
                      selectedColor: AppColors.neonPurple,
                      onSelected: _isRendering ? null : (_) => setState(() => _aspectRatio = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [2.0, 3.0, 4.0, 5.0].map((d) {
                    return ChoiceChip(
                      label: Text('${d.toInt()}s / photo'),
                      selected: _photoDurationSec == d,
                      selectedColor: AppColors.neonBlue,
                      onSelected: _isRendering ? null : (_) => setState(() => _photoDurationSec = d),
                    );
                  }).toList(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Blur Background Frame'),
                  subtitle: const Text('Photo nahi kategi + premium blurred frame banega'),
                  value: _blurBackgroundFrame,
                  activeThumbColor: AppColors.neonCyan,
                  onChanged: _isRendering ? null : (v) => setState(() => _blurBackgroundFrame = v),
                ),
                const Divider(color: Colors.white12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Background Music'),
                  subtitle: Text(_musicTitle, style: const TextStyle(color: AppColors.neonCyan, fontSize: 12)),
                  value: _useMusic,
                  activeThumbColor: AppColors.neonPink,
                  onChanged: _isRendering ? null : (v) => setState(() => _useMusic = v),
                ),
                if (_useMusic) ...[
                  OutlinedButton.icon(
                    onPressed: _isRendering ? null : _pickMusic,
                    icon: const Icon(Icons.music_note_rounded, color: AppColors.neonPink),
                    label: const Text('Change Music (8 Built-In Packs / Phone MP3)'),
                  ),
                  Row(
                    children: [
                      const Text('Vol:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      Expanded(
                        child: Slider(
                          value: _musicVolume,
                          min: 0.1,
                          max: 1.0,
                          activeColor: AppColors.neonPink,
                          onChanged: _isRendering ? null : (v) => setState(() => _musicVolume = v),
                        ),
                      ),
                      Text('${(_musicVolume * 100).round()}%'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isRendering) ...[
            const LinearProgressIndicator(color: AppColors.neonPink, backgroundColor: Colors.white12),
            const SizedBox(height: 8),
            Text(_renderStatus, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neonCyan)),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: _isRendering ? null : _generatePhotoVideo,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: Text(
              _isRendering ? 'Creating Video...' : 'Create Photo Reel & Save to Gallery',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
}

// ============================================================================
// 10. VIDEO STUDIO EDITOR SCREEN
// ============================================================================
class VideoStudioEditorScreen extends StatefulWidget {
  final String videoPath;
  final String videoName;
  final int initialToolTab;
  final String? initialEffectId;

  const VideoStudioEditorScreen({
    super.key,
    required this.videoPath,
    required this.videoName,
    this.initialToolTab = 0,
    this.initialEffectId,
  });

  @override
  State<VideoStudioEditorScreen> createState() => _VideoStudioEditorScreenState();
}

class _VideoStudioEditorScreenState extends State<VideoStudioEditorScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  double _totalSeconds = 1.0;
  RangeValues _trimRange = const RangeValues(0, 1);

  int _activeTool = 0;
  String _selectedRatio = 'Original';
  double _selectedSpeed = 1.0;
  int _rotationDeg = 0;
  String _flipMode = 'None';
  bool _muteAudio = false;
  double _originalVolume = 1.0;
  String? _bgMusicPath;
  String? _bgMusicTitle;
  double _bgMusicVolume = 0.65;
  VideoEffectPreset _selectedEffect = kStudioEffects.first;
  String _quickResolution = '1080P';

  @override
  void initState() {
    super.initState();
    _activeTool = widget.initialToolTab;
    if (widget.initialEffectId != null) {
      _selectedEffect = kStudioEffects.firstWhere(
        (e) => e.id == widget.initialEffectId,
        orElse: () => kStudioEffects.first,
      );
    }
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

  void _resetAll() {
    setState(() {
      _trimRange = RangeValues(0, _totalSeconds);
      _selectedRatio = 'Original';
      _selectedSpeed = 1.0;
      _rotationDeg = 0;
      _flipMode = 'None';
      _muteAudio = false;
      _originalVolume = 1.0;
      _bgMusicPath = null;
      _bgMusicTitle = null;
      _selectedEffect = kStudioEffects.first;
    });
    _controller?.setPlaybackSpeed(1.0);
    _controller?.setVolume(1.0);
  }

  Future<void> _pickMusicForVideo() async {
    await _controller?.pause();
    if (!mounted) return;
    final res = await Navigator.of(context).push<SelectedMusicResult>(
      MaterialPageRoute(builder: (_) => const StudioMusicLibraryScreen(pickerMode: true)),
    );
    if (res != null && mounted) {
      setState(() {
        _bgMusicPath = res.path;
        _bgMusicTitle = res.title;
      });
    }
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
          originalVolume: _originalVolume,
          bgMusicPath: _bgMusicPath,
          bgMusicTitle: _bgMusicTitle,
          bgMusicVolume: _bgMusicVolume,
          effect: _selectedEffect,
          initialResolution: _quickResolution,
        ),
      ),
    );

    if (exportedPath != null && mounted) {
      Navigator.of(context).pop(exportedPath);
    }
  }

  Widget _buildVideoPreviewWithLiveEffect() {
    Widget vid = AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );

    if (_selectedEffect.id != 'none') {
      vid = ColorFiltered(
        colorFilter: ColorFilter.matrix(_selectedEffect.previewMatrix),
        child: vid,
      );
      if (_selectedEffect.previewBlur > 0) {
        vid = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: _selectedEffect.previewBlur,
            sigmaY: _selectedEffect.previewBlur,
          ),
          child: vid,
        );
      }
    }

    return ClipRRect(borderRadius: BorderRadius.circular(16), child: vid);
  }

  Widget _buildToolControls() {
    switch (_activeTool) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Start: ${formatClock(_trimRange.start)}', style: const TextStyle(color: AppColors.neonCyan)),
                Text('Clip: ${formatClock(_trimRange.end - _trimRange.start)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('End: ${formatClock(_trimRange.end)}', style: const TextStyle(color: AppColors.neonPink)),
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

      case 1:
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

      case 2:
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

      case 3:
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

      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMusicForVideo,
                    icon: const Icon(Icons.music_note_rounded, color: AppColors.neonPink, size: 18),
                    label: Text(_bgMusicTitle ?? 'Add Built-In Music / MP3', overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (_bgMusicPath != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    onPressed: () => setState(() {
                      _bgMusicPath = null;
                      _bgMusicTitle = null;
                    }),
                  ),
              ],
            ),
            if (_bgMusicPath != null)
              Row(
                children: [
                  const Text('Music Vol:', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _bgMusicVolume,
                      min: 0.1,
                      max: 1.0,
                      activeColor: AppColors.neonPink,
                      onChanged: (v) => setState(() => _bgMusicVolume = v),
                    ),
                  ),
                  Text('${(_bgMusicVolume * 100).round()}%', style: const TextStyle(fontSize: 12)),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mute Original Video Audio', style: TextStyle(fontSize: 13)),
                Switch(
                  value: _muteAudio,
                  activeThumbColor: AppColors.neonCyan,
                  onChanged: (v) {
                    setState(() => _muteAudio = v);
                    _controller?.setVolume(v ? 0.0 : _originalVolume);
                  },
                ),
              ],
            ),
          ],
        );

      case 5:
      default:
        return SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: kStudioEffects.length,
            itemBuilder: (ctx, idx) {
              final fx = kStudioEffects[idx];
              final active = _selectedEffect.id == fx.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedEffect = fx),
                child: Container(
                  width: 82,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: active ? fx.accent.withValues(alpha: 0.25) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? fx.accent : Colors.white12, width: active ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(fx.icon, color: fx.accent, size: 22),
                      const SizedBox(height: 4),
                      Text(fx.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posSec = (_controller?.value.position.inMilliseconds ?? 0) / 1000.0;
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoName, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _quickResolution,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              items: ['480P', '720P', '1080P', 'Original']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _quickResolution = v);
              },
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
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
                        _buildVideoPreviewWithLiveEffect(),
                        if (_selectedEffect.id != 'none')
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _selectedEffect.accent),
                              ),
                              child: Text(
                                'FX: ${_selectedEffect.name}',
                                style: TextStyle(
                                  color: _selectedEffect.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => isPlaying ? _controller!.pause() : _controller!.play(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 38,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${formatClock(posSec)} / ${formatClock(_totalSeconds)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Reset all edits',
                      onPressed: _resetAll,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                    ),
                    IconButton(
                      onPressed: _controller == null
                          ? null
                          : () => isPlaying ? _controller!.pause() : _controller!.play(),
                      icon: Icon(
                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: AppColors.neonCyan,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.neonPurple, AppColors.neonBlue]),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'VIDEO  •  FX: ${_selectedEffect.name}  •  Crop: $_selectedRatio  •  ${_selectedSpeed}x',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _bgMusicPath != null
                        ? AppColors.neonPink.withValues(alpha: 0.25)
                        : AppColors.neonCyan.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _bgMusicPath != null
                        ? 'MUSIC  •  $_bgMusicTitle (${(_bgMusicVolume * 100).round()}%)'
                        : (_muteAudio ? 'AUDIO  •  Muted' : 'AUDIO  •  Original  •  Rotate: $_rotationDeg°'),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _buildToolControls(),
          ),
          const SizedBox(height: 8),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _editorTabBtn(0, Icons.content_cut_rounded, 'Trim'),
                _editorTabBtn(5, Icons.auto_fix_high_rounded, 'Effects'),
                _editorTabBtn(4, Icons.music_note_rounded, 'Music'),
                _editorTabBtn(1, Icons.crop_rounded, 'Crop'),
                _editorTabBtn(2, Icons.speed_rounded, 'Speed'),
                _editorTabBtn(3, Icons.rotate_90_degrees_cw_rounded, 'Rotate'),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.neonCyan : Colors.white60, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
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
// 11. UNIFIED FFMPEG EXPORT SCREEN (Now with 60 FPS Smooth Gaming Mode)
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
  final double originalVolume;
  final String? bgMusicPath;
  final String? bgMusicTitle;
  final double bgMusicVolume;
  final VideoEffectPreset effect;
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
    required this.originalVolume,
    required this.bgMusicPath,
    required this.bgMusicTitle,
    required this.bgMusicVolume,
    required this.effect,
    required this.initialResolution,
  });

  @override
  State<ExportConfigScreen> createState() => _ExportConfigScreenState();
}

class _ExportConfigScreenState extends State<ExportConfigScreen> {
  late String _resolution;
  bool _use60Fps = false;
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
      _statusText = 'FFmpeg Studio rendering ${_use60Fps ? "60 FPS " : ""}video...';
    });

    try {
      if (_saveToGallery) {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) await Gal.requestAccess(toAlbum: true);
      }

      final hasOrigAudio = await checkVideoHasAudio(widget.videoPath);
      final double clipDur = math.max(0.5, widget.endSec - widget.startSec);
      final double outDur = clipDur / widget.speed;

      final List<String> vf = [];
      if (widget.aspectRatio == '9:16') {
        vf.add(r'crop=min(iw\,ih*9/16):min(ih\,iw*16/9)');
      } else if (widget.aspectRatio == '1:1') {
        vf.add(r'crop=min(iw\,ih):min(iw\,ih)');
      } else if (widget.aspectRatio == '16:9') {
        vf.add(r'crop=min(iw\,ih*16/9):min(ih\,iw*9/16)');
      }

      if (widget.rotationDeg == 90) {
        vf.add('transpose=1');
      } else if (widget.rotationDeg == 180) {
        vf.add('transpose=1,transpose=1');
      } else if (widget.rotationDeg == 270) {
        vf.add('transpose=2');
      }

      if (widget.flipMode == 'Horizontal') {
        vf.add('hflip');
      } else if (widget.flipMode == 'Vertical') {
        vf.add('vflip');
      }

      if (widget.speed != 1.0) {
        vf.add('setpts=PTS/${widget.speed.toStringAsFixed(2)}');
      }

      if (widget.effect.ffmpegFilter.isNotEmpty) {
        vf.add(widget.effect.ffmpegFilter);
      }

      if (_resolution == '480P') {
        vf.add(r'scale=if(gte(iw\,ih)\,-2\,min(iw\,480)):if(gte(iw\,ih)\,min(ih\,480)\,-2)');
      } else if (_resolution == '720P') {
        vf.add(r'scale=if(gte(iw\,ih)\,-2\,min(iw\,720)):if(gte(iw\,ih)\,min(ih\,720)\,-2)');
      } else if (_resolution == '1080P') {
        vf.add(r'scale=if(gte(iw\,ih)\,-2\,min(iw\,1080)):if(gte(iw\,ih)\,min(ih\,1080)\,-2)');
      }
      vf.add('scale=trunc(iw/2)*2:trunc(ih/2)*2');

      if (_use60Fps) {
        vf.add('fps=60');
      }

      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/vcs_edit_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final List<String> args = [
        '-y',
        '-ss',
        widget.startSec.toStringAsFixed(2),
        '-i',
        widget.videoPath,
        '-t',
        clipDur.toStringAsFixed(2),
      ];

      if (widget.bgMusicPath != null) {
        args.addAll(['-stream_loop', '-1', '-i', widget.bgMusicPath!]);

        final List<String> fc = [];
        fc.add('[0:v]${vf.join(",")},format=yuv420p[vout]');

        final double fadeOutSt = math.max(0.0, outDur - 1.2);
        fc.add(
          '[1:a]volume=${widget.bgMusicVolume.toStringAsFixed(2)},'
          'afade=t=in:st=0:d=0.6,afade=t=out:st=${fadeOutSt.toStringAsFixed(2)}:d=1.2[mus]',
        );

        if (!widget.muteAudio && hasOrigAudio && widget.originalVolume > 0.02) {
          final String origA = widget.speed != 1.0
              ? '[0:a]atempo=${widget.speed.toStringAsFixed(2)},volume=${widget.originalVolume.toStringAsFixed(2)}[orig]'
              : '[0:a]volume=${widget.originalVolume.toStringAsFixed(2)}[orig]';
          fc.add(origA);
          fc.add('[orig][mus]amix=inputs=2:duration=first:dropout_transition=2[aout]');
          args.addAll(['-filter_complex', fc.join(';'), '-map', '[vout]', '-map', '[aout]']);
        } else {
          args.addAll(['-filter_complex', fc.join(';'), '-map', '[vout]', '-map', '[mus]']);
        }

        args.addAll(['-t', outDur.toStringAsFixed(2), '-c:a', 'aac', '-b:a', '128k']);
      } else {
        args.addAll(['-vf', vf.join(',')]);
        if (widget.muteAudio || !hasOrigAudio) {
          args.add('-an');
        } else {
          final List<String> af = [];
          if (widget.speed != 1.0) af.add('atempo=${widget.speed.toStringAsFixed(2)}');
          if ((widget.originalVolume - 1.0).abs() > 0.02) {
            af.add('volume=${widget.originalVolume.toStringAsFixed(2)}');
          }
          if (af.isNotEmpty) {
            args.addAll(['-af', af.join(',')]);
          }
          args.addAll(['-c:a', 'aac', '-b:a', '128k']);
        }
      }

      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '23',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outPath,
      ]);

      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();

      if (!ReturnCode.isSuccess(rc) || !File(outPath).existsSync()) {
        final logs = await session.getOutput();
        throw Exception(logs?.split('\n').last ?? 'FFmpeg render failed');
      }

      if (_saveToGallery) {
        await Gal.putVideo(outPath, album: 'Viral Clip Studio');
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExportSuccessScreen(outputPath: outPath, savedToGallery: _saveToGallery),
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
                  'Effect: ${widget.effect.name}  •  Crop: ${widget.aspectRatio}  •  Speed: ${widget.speed}x\n'
                  'Music: ${widget.bgMusicTitle ?? "None"}  •  Mute Orig: ${widget.muteAudio ? "Yes" : "No"}',
                  style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('60 FPS Smooth Gaming Mode'),
                  subtitle: const Text('Ultra-smooth motion (Gameplay/Action)'),
                  value: _use60Fps,
                  activeThumbColor: AppColors.neonCyan,
                  onChanged: _isExporting ? null : (v) => setState(() => _use60Fps = v),
                ),
                const Divider(color: Colors.white12, height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Save to Gallery'),
                  subtitle: const Text('Album: Viral Clip Studio'),
                  value: _saveToGallery,
                  activeThumbColor: AppColors.neonPurple,
                  onChanged: _isExporting ? null : (v) => setState(() => _saveToGallery = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                        Share.shareXFiles([XFile(outputPath)], text: 'Edited with Viral Clip Studio');
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
