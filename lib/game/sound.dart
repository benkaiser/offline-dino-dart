import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Sound effects for the Dino game using the original Chromium audio files.
///
/// The original Chrome Dino game ships three Ogg Vorbis audio files
/// (mislabeled as .mp3 in the source). We bundle the actual files as
/// Flutter assets and copy them to a temporary directory for playback.
class GameSounds {
  final AudioPlayer _jumpPlayer = AudioPlayer();
  final AudioPlayer _scorePlayer = AudioPlayer();
  final AudioPlayer _gameOverPlayer = AudioPlayer();

  String? _jumpPath;
  String? _scorePath;
  String? _gameOverPath;

  bool _initialised = false;

  /// Load audio assets from the bundle and write them to temp files.
  /// Must be called once before playing any sounds.
  Future<void> init() async {
    try {
      final dir = await getTemporaryDirectory();
      final soundDir = Directory('${dir.path}/dino_sounds');
      if (!soundDir.existsSync()) {
        soundDir.createSync(recursive: true);
      }

      _jumpPath = await _copyAsset(
          'assets/button-press.ogg', '${soundDir.path}/button-press.ogg');
      _scorePath = await _copyAsset(
          'assets/score-reached.ogg', '${soundDir.path}/score-reached.ogg');
      _gameOverPath =
          await _copyAsset('assets/hit.ogg', '${soundDir.path}/hit.ogg');

      _initialised = true;
    } catch (e) {
      // Sounds will be silently disabled if asset copy fails.
      _initialised = false;
    }
  }

  Future<String> _copyAsset(String assetPath, String destPath) async {
    final data = await rootBundle.load(assetPath);
    final file = File(destPath);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ──────────────────────────────────────────────────────────────────────

  void playJump() {
    if (!_initialised || _jumpPath == null) return;
    _jumpPlayer.stop();
    _jumpPlayer.play(DeviceFileSource(_jumpPath!));
  }

  void playScore() {
    if (!_initialised || _scorePath == null) return;
    _scorePlayer.stop();
    _scorePlayer.play(DeviceFileSource(_scorePath!));
  }

  void playGameOver() {
    if (!_initialised || _gameOverPath == null) return;
    _gameOverPlayer.stop();
    _gameOverPlayer.play(DeviceFileSource(_gameOverPath!));
  }

  void dispose() {
    _jumpPlayer.dispose();
    _scorePlayer.dispose();
    _gameOverPlayer.dispose();
  }
}
