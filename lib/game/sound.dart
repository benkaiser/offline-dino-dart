import 'package:flame_audio/flame_audio.dart';

/// Sound effects for the Dino game using the original Chromium audio files.
///
/// We keep a small round-robin pool of [AudioPlayer] instances per effect,
/// each pre-loaded with its source in [PlayerMode.lowLatency] mode.
/// On Android this routes through the native SoundPool backend; the `.wav`
/// (PCM) assets need no runtime decoding.
///
/// Pre-loading means the first play is just as fast as subsequent ones —
/// no file I/O or native-player setup happens on the hot path.
class GameSounds {
  static const int _poolSize = 2;

  final List<AudioPlayer> _jumpPlayers = [];
  final List<AudioPlayer> _scorePlayers = [];
  final List<AudioPlayer> _gameOverPlayers = [];

  int _jumpIndex = 0;
  int _scoreIndex = 0;
  int _gameOverIndex = 0;

  bool _initialised = false;

  /// Pre-cache the audio files and warm up player pools.
  Future<void> init() async {
    try {
      // Copy assets to temp files so the native side can access them.
      await FlameAudio.audioCache.loadAll([
        'button-press.wav',
        'score-reached.wav',
        'hit.wav',
      ]);

      // Create pre-loaded player pools.
      for (var i = 0; i < _poolSize; i++) {
        _jumpPlayers.add(
          await _createPlayer('button-press.wav'),
        );
        _scorePlayers.add(
          await _createPlayer('score-reached.wav'),
        );
        _gameOverPlayers.add(
          await _createPlayer('hit.wav'),
        );
      }

      _initialised = true;
    } catch (e) {
      // Sounds will be silently disabled if loading fails.
      _initialised = false;
    }
  }

  Future<AudioPlayer> _createPlayer(String file) async {
    final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
    await player.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setSource(AssetSource(file));
    await player.setReleaseMode(ReleaseMode.stop);
    return player;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ──────────────────────────────────────────────────────────────────────

  void playJump() => _play(_jumpPlayers, _jumpIndex++);

  void playScore() => _play(_scorePlayers, _scoreIndex++);

  void playGameOver() => _play(_gameOverPlayers, _gameOverIndex++);

  void _play(List<AudioPlayer> pool, int index) {
    if (!_initialised) return;
    final player = pool[index % _poolSize];
    // stop resets position to the start; resume plays from there.
    player.stop().then((_) => player.resume());
  }

  void dispose() {
    for (final p in [..._jumpPlayers, ..._scorePlayers, ..._gameOverPlayers]) {
      p.dispose();
    }
    FlameAudio.audioCache.clearAll();
  }
}
