import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'trex.dart';
import 'horizon.dart';
import 'obstacle.dart';
import 'sound.dart';
import 'sprites.dart';

/// The possible states of the game.
enum GameState {
  waiting,
  playing,
  paused,
  crashed,
}

/// Main game engine for the Chrome Dino clone.
///
/// Coordinates the T-Rex, horizon (ground, clouds, obstacles), collision
/// detection, scoring, and night-mode cycling.
class DinoGame {
  // ── Game state ───────────────────────────────────────────────────────────
  GameState gameState = GameState.waiting;
  double currentSpeed = GameConstants.initialSpeed;
  double distanceRan = 0;
  int highScore = 0;

  /// The current score, derived from distance.
  int get score => (distanceRan * GameConstants.scoreCoefficient).round();

  /// Milliseconds elapsed while in the [GameState.playing] state.
  double runningTime = 0;

  // ── Components ──────────────────────────────────────────────────────────
  late TRex tRex;
  late Horizon horizon;

  // ── Night-mode cycling ──────────────────────────────────────────────────
  bool showNightMode = false;
  double invertTimer = 0;
  int _lastInvertTrigger = 0; // score at which night mode was last toggled

  // ── Game-over delay ─────────────────────────────────────────────────────
  double gameOverTimer = 0;

  // ── Score flash (achievement every 100 points) ────────────────────────
  double _scoreFlashTimer = 0;
  int _scoreFlashCount = 0;
  int _lastAchievementScore = 0;
  bool _scoreVisible = true;

  // ── Canvas dimensions ───────────────────────────────────────────────────
  final double canvasWidth;

  // ── Sprite sheet ──────────────────────────────────────────────────────
  final SpriteSheet sprites = SpriteSheet();

  // ── Sound effects ──────────────────────────────────────────────────────
  final GameSounds sounds = GameSounds();

  // ── Text style constants ────────────────────────────────────────────────
  static const Color _textColor = Color(0xFF535353);

  // ──────────────────────────────────────────────────────────────────────
  //  CONSTRUCTOR
  // ──────────────────────────────────────────────────────────────────────

  DinoGame({required this.canvasWidth}) {
    tRex = TRex();
    horizon = Horizon(canvasWidth: canvasWidth);
  }

  // ──────────────────────────────────────────────────────────────────────
  //  INITIALISATION
  // ──────────────────────────────────────────────────────────────────────

  /// Load the sprite sheet, sounds, and any other async resources.
  Future<void> init() async {
    await sprites.load();
    await sounds.init();
    await _loadHighScore();
  }

  static const String _highScoreKey = 'dino_high_score';

  Future<void> _loadHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      highScore = prefs.getInt(_highScoreKey) ?? 0;
    } catch (_) {
      // If prefs fail, just start with 0.
    }
  }

  Future<void> _saveHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_highScoreKey, highScore);
    } catch (_) {
      // Best-effort save.
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  UPDATE
  // ──────────────────────────────────────────────────────────────────────

  /// Main game-loop tick.  [deltaTime] is in **milliseconds**.
  void update(double deltaTime) {
    switch (gameState) {
      case GameState.waiting:
        // Only update the T-Rex (idle blinking animation).
        tRex.update(deltaTime);
        break;

      case GameState.playing:
        _updatePlaying(deltaTime);
        break;

      case GameState.paused:
        // Frozen — no updates.
        break;

      case GameState.crashed:
        // Tick the game-over timer so the player can't instantly restart.
        gameOverTimer += deltaTime;
        break;
    }
  }

  void _updatePlaying(double deltaTime) {
    runningTime += deltaTime;

    // Obstacles appear after clearTime.
    final bool hasObstacles = runningTime > GameConstants.clearTime;

    // Update components.
    tRex.update(deltaTime);
    horizon.update(deltaTime, currentSpeed, hasObstacles, showNightMode);

    // ── Collision detection ──────────────────────────────────────────────
    if (hasObstacles && horizon.obstacles.isNotEmpty && checkCollision()) {
      gameOver();
      return;
    }

    // ── Distance & speed ─────────────────────────────────────────────────
    distanceRan += currentSpeed * deltaTime / GameConstants.msPerFrame;

    if (currentSpeed < GameConstants.maxSpeed) {
      currentSpeed += GameConstants.acceleration;
    }

    // ── Night-mode cycling ───────────────────────────────────────────────
    _updateNightMode(deltaTime);

    // ── Score achievement flash ───────────────────────────────────────────
    _updateScoreFlash(deltaTime);
  }

  void _updateNightMode(double deltaTime) {
    final int currentScore = score;
    final int invertDistance = GameConstants.invertDistance.toInt();

    if (invertDistance > 0) {
      // Check if we've crossed an invertDistance boundary.
      final int trigger = currentScore ~/ invertDistance;
      if (trigger > _lastInvertTrigger) {
        _lastInvertTrigger = trigger;
        showNightMode = !showNightMode;
        invertTimer = 0;
      }

      // Auto-revert night mode after invertFadeDuration.
      if (showNightMode) {
        invertTimer += deltaTime;
        if (invertTimer >= GameConstants.invertFadeDuration) {
          showNightMode = false;
          invertTimer = 0;
        }
      }
    }
  }

  void _updateScoreFlash(double deltaTime) {
    final int currentScore = score;
    final int achievementDistance = GameConstants.achievementDistance;

    // Trigger flash when crossing an achievement boundary.
    if (currentScore > 0 && achievementDistance > 0) {
      final int achievementNum = currentScore ~/ achievementDistance;
      if (achievementNum > _lastAchievementScore) {
        _lastAchievementScore = achievementNum;
        _scoreFlashTimer = 0;
        _scoreFlashCount = 0;
        _scoreVisible = false; // Start with invisible (flash off)
        sounds.playScore();
      }
    }

    // Animate the flash.
    if (_scoreFlashCount < GameConstants.flashIterations * 2) {
      _scoreFlashTimer += deltaTime;
      if (_scoreFlashTimer >= GameConstants.flashDuration) {
        _scoreFlashTimer = 0;
        _scoreFlashCount++;
        _scoreVisible = !_scoreVisible;
      }
    } else {
      _scoreVisible = true;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  COLLISION DETECTION
  // ──────────────────────────────────────────────────────────────────────

  /// Two-phase AABB collision check between the T-Rex and the first
  /// (nearest) obstacle.
  bool checkCollision() {
    if (horizon.obstacles.isEmpty) return false;

    final Obstacle obstacle = horizon.obstacles.first;

    // ── Phase 1: Outer bounding boxes (slightly shrunk for fairness) ────
    final double tRexX = tRex.xPos + 1;
    final double tRexY = tRex.yPos + 1;
    final double tRexW = tRex.width - 2;
    final double tRexH = tRex.height - 2;

    final double obsX = obstacle.xPos + 1;
    final double obsY = obstacle.yPos + 1;
    final double obsW = obstacle.width - 2;
    final double obsH = obstacle.height - 2;

    // Quick AABB rejection.
    if (!_boxesOverlap(tRexX, tRexY, tRexW, tRexH, obsX, obsY, obsW, obsH)) {
      return false;
    }

    // ── Phase 2: Per-collision-box check ──────────────────────────────────
    final List<CollisionBox> tRexBoxes = tRex.collisionBoxes;
    final List<CollisionBox> obstacleBoxes = obstacle.getCollisionBoxes();

    for (final tBox in tRexBoxes) {
      // T-Rex collision boxes are relative to (xPos, yPos).
      final double ax = tBox.x + tRex.xPos;
      final double ay = tBox.y + tRex.yPos;
      final double aw = tBox.width;
      final double ah = tBox.height;

      for (final oBox in obstacleBoxes) {
        // Obstacle collision boxes are already in world coordinates
        // (getCollisionBoxes adds xPos/yPos offsets).
        if (_boxesOverlap(ax, ay, aw, ah, oBox.x, oBox.y, oBox.width, oBox.height)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Standard AABB overlap test.
  bool _boxesOverlap(
    double ax, double ay, double aw, double ah,
    double bx, double by, double bw, double bh,
  ) {
    return ax < bx + bw &&
        ax + aw > bx &&
        ay < by + bh &&
        ay + ah > by;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  GAME STATE TRANSITIONS
  // ──────────────────────────────────────────────────────────────────────

  /// Begin a new game from the waiting state.
  void startGame() {
    gameState = GameState.playing;
    tRex.status = TRexStatus.running;
    currentSpeed = GameConstants.initialSpeed;
    distanceRan = 0;
    runningTime = 0;
    showNightMode = false;
    invertTimer = 0;
    _lastInvertTrigger = 0;
  }

  /// Transition to the crashed state.
  void gameOver() {
    gameState = GameState.crashed;
    tRex.status = TRexStatus.crashed;
    sounds.playGameOver();

    // Persist high score.
    final int currentScore = score;
    if (currentScore > highScore) {
      highScore = currentScore;
      _saveHighScore();
    }

    gameOverTimer = 0;
  }

  /// Restart the game after a crash (subject to a cooldown delay).
  void restart() {
    if (gameOverTimer < GameConstants.gameOverClearTime) return;

    // Reset all state.
    tRex.reset();
    horizon.reset();
    distanceRan = 0;
    currentSpeed = GameConstants.initialSpeed;
    runningTime = 0;
    showNightMode = false;
    invertTimer = 0;
    _lastInvertTrigger = 0;
    gameOverTimer = 0;
    _scoreFlashTimer = 0;
    _scoreFlashCount = 0;
    _lastAchievementScore = 0;
    _scoreVisible = true;

    // Immediately start playing.
    gameState = GameState.playing;
    tRex.status = TRexStatus.running;
  }

  /// Pause the game (only while playing).
  void pause() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
    }
  }

  /// Resume from a paused state.
  void resume() {
    if (gameState == GameState.paused) {
      gameState = GameState.playing;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  INPUT HANDLERS
  // ──────────────────────────────────────────────────────────────────────

  /// Jump / tap handler — responds to spacebar, tap, or arrow-up.
  void onAction() {
    switch (gameState) {
      case GameState.waiting:
        startGame();
        tRex.startJump(currentSpeed);
        sounds.playJump();
        break;
      case GameState.playing:
        if (!tRex.jumping) {
          sounds.playJump();
        }
        tRex.startJump(currentSpeed);
        break;
      case GameState.paused:
        resume();
        break;
      case GameState.crashed:
        restart();
        break;
    }
  }

  /// Release handler — ends a jump early when the key/touch is released.
  void onActionEnd() {
    tRex.endJump();
  }

  /// Duck handler — toggle ducking on or off.
  void onDuck(bool isDucking) {
    tRex.setDuck(isDucking);
  }

  // ──────────────────────────────────────────────────────────────────────
  //  DRAW
  // ──────────────────────────────────────────────────────────────────────

  /// Renders the entire game scene to [canvas] at the given [size].
  ///
  /// [isMobile] controls whether hint text mentions keyboard keys.
  void draw(Canvas canvas, Size size, {bool isMobile = false}) {
    // ── If sprites aren't loaded yet, just draw a gray background ────────
    if (!sprites.isLoaded) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF7F7F7),
      );
      return;
    }

    // ── Background ───────────────────────────────────────────────────────
    final Color bgColor =
        showNightMode ? const Color(0xFF303030) : const Color(0xFFF7F7F7);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // ── Horizon (clouds, ground, obstacles) ──────────────────────────────
    horizon.draw(canvas, size, sprites, showNightMode);

    // ── T-Rex ────────────────────────────────────────────────────────────
    tRex.draw(canvas, size, showNightMode, sprites);

    // ── Score display ────────────────────────────────────────────────────
    _drawScore(canvas, size);

    // ── Waiting state hint ────────────────────────────────────────────────
    if (gameState == GameState.waiting) {
      _drawStartHint(canvas, size, isMobile: isMobile);
    }

    // ── Paused overlay ───────────────────────────────────────────────────
    if (gameState == GameState.paused) {
      _drawPaused(canvas, size, isMobile: isMobile);
    }

    // ── Game-over overlay ────────────────────────────────────────────────
    if (gameState == GameState.crashed) {
      _drawGameOver(canvas, size);
    }
  }

  void _drawScore(Canvas canvas, Size size) {
    if (!_scoreVisible && gameState == GameState.playing) return;

    final bool nightMode = showNightMode;

    // ── Digit dimensions ─────────────────────────────────────────────────
    const double digitDestW = 11; // 10px digit + 1px gap
    const double scoreY = 5;
    const double rightPadding = 10;

    // ── Current score (5 digits, right-aligned at top-right) ─────────────
    final String scoreText = score.toString().padLeft(5, '0');
    final double scoreStartX =
        size.width - rightPadding - (scoreText.length * digitDestW);

    for (int i = 0; i < scoreText.length; i++) {
      final int digit = int.parse(scoreText[i]);
      sprites.drawDigit(
        canvas,
        scoreStartX + i * digitDestW,
        scoreY,
        digit,
        nightMode: nightMode,
      );
    }

    // ── High score ("HI 00000", to the left of current score) ────────────
    if (highScore > 0) {
      final String hiScoreText = highScore.toString().padLeft(5, '0');
      // Layout: HI(20px) + gap(8px) + 5 digits + gap(8px) + current score
      const double hiW = 20; // "HI" label width
      const double gap = 8;
      final double hiDigitsW = hiScoreText.length * digitDestW;
      final double hiStartX =
          scoreStartX - gap - hiDigitsW - gap - hiW;

      sprites.drawHI(canvas, hiStartX, scoreY, nightMode: nightMode);

      final double hiDigitsStartX = hiStartX + hiW + gap;
      for (int i = 0; i < hiScoreText.length; i++) {
        final int digit = int.parse(hiScoreText[i]);
        sprites.drawDigit(
          canvas,
          hiDigitsStartX + i * digitDestW,
          scoreY,
          digit,
          nightMode: nightMode,
        );
      }
    }
  }

  void _drawStartHint(Canvas canvas, Size size, {bool isMobile = false}) {
    final String hintText =
        isMobile ? 'Tap to Start' : 'Press Space or Tap to Start';
    final TextPainter hintPainter = TextPainter(
      text: TextSpan(
        text: hintText,
        style: TextStyle(
          color: _textColor.withValues(alpha: 0.6),
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hintPainter.paint(
      canvas,
      Offset(
        (size.width - hintPainter.width) / 2,
        size.height / 2 - 10,
      ),
    );
  }

  void _drawPaused(Canvas canvas, Size size, {bool isMobile = false}) {
    final String resumeText =
        isMobile ? 'Tap to Resume' : 'Press Space or Tap to Resume';
    final TextPainter pausePainter = TextPainter(
      text: TextSpan(
        text: resumeText,
        style: TextStyle(
          color: _textColor.withValues(alpha: 0.6),
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pausePainter.paint(
      canvas,
      Offset(
        (size.width - pausePainter.width) / 2,
        size.height / 2 - 10,
      ),
    );
  }

  void _drawGameOver(Canvas canvas, Size size) {
    final bool nightMode = showNightMode;

    // "GAME OVER" sprite — 191×11, centred horizontally.
    const double gameOverW = 191;
    const double gameOverH = 11;
    final double gameOverX = (size.width - gameOverW) / 2;
    final double gameOverY = size.height / 2 - 30;
    sprites.drawGameOver(canvas, gameOverX, gameOverY, nightMode: nightMode);

    // Restart button sprite — 36×32, centred below "GAME OVER".
    const double restartW = 36;
    final double restartX = (size.width - restartW) / 2;
    final double restartY = gameOverY + gameOverH + 10;
    sprites.drawRestart(canvas, restartX, restartY, nightMode: nightMode);
  }
}
