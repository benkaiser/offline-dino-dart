import 'dart:math';
import 'dart:ui';

import 'constants.dart';
import 'sprites.dart';

/// The states a T-Rex can be in.
enum TRexStatus {
  waiting,
  running,
  jumping,
  ducking,
  crashed,
}

/// The T-Rex player character.
///
/// Uses the Chrome Dino sprite sheet for rendering.
class TRex {
  // ── Position & dimensions ──────────────────────────────────────────────
  double xPos = TRexConfig.startXPos;
  double yPos = TRexConfig.groundYPos;

  double get width =>
      status == TRexStatus.ducking ? TRexConfig.widthDuck : TRexConfig.width;
  double get height =>
      status == TRexStatus.ducking ? TRexConfig.heightDuck : TRexConfig.height;

  // ── State ──────────────────────────────────────────────────────────────
  TRexStatus status = TRexStatus.waiting;

  // ── Jump physics ───────────────────────────────────────────────────────
  double jumpVelocity = 0;
  bool jumping = false;
  bool ducking = false;
  bool reachedMinHeight = false;
  bool speedDrop = false;
  int jumpCount = 0;

  /// When true, the T-Rex will duck as soon as it lands from a jump.
  /// Set by touch input when a downward swipe is detected mid-air.
  bool duckQueued = false;

  // ── Blink animation (waiting state) ────────────────────────────────────
  static const int _maxBlinkCount = 3;
  int _blinkCount = 0;
  double _blinkTimer = 0;
  double _blinkDelay = 0;
  bool _isBlinking = false;
  static const double _blinkDuration = 100; // ms the eye stays closed
  final Random _random = Random();

  // ── Running / ducking leg animation ────────────────────────────────────
  double _runTimer = 0;
  int _currentRunFrame = 0; // 0 or 1
  static const double _runFrameRate = 83; // ms per frame (running)
  static const double _duckFrameRate = 125; // ms per frame (ducking)

  // ── Intro slide-in ─────────────────────────────────────────────────────
  // ignore: unused_field
  double _introTimer = 0;
  bool playingIntro = false;

  // ── Collision boxes (exposed for collision detection) ───────────────────
  List<CollisionBox> get collisionBoxes =>
      status == TRexStatus.ducking
          ? trexDuckingCollisionBoxes
          : trexRunningCollisionBoxes;

  // ──────────────────────────────────────────────────────────────────────
  //  UPDATE
  // ──────────────────────────────────────────────────────────────────────

  /// [deltaTime] is elapsed time in **milliseconds** since the last frame.
  void update(double deltaTime) {
    final double framesElapsed = deltaTime / GameConstants.msPerFrame;

    switch (status) {
      case TRexStatus.waiting:
        _updateWaiting(deltaTime);
        break;
      case TRexStatus.running:
        _updateRunning(deltaTime);
        break;
      case TRexStatus.jumping:
        _updateJumping(framesElapsed);
        break;
      case TRexStatus.ducking:
        _updateDucking(deltaTime);
        break;
      case TRexStatus.crashed:
        break;
    }
  }

  void _updateWaiting(double deltaTime) {
    _blinkTimer += deltaTime;

    if (_isBlinking) {
      // Close eye for a short duration then reopen.
      if (_blinkTimer >= _blinkDuration) {
        _isBlinking = false;
        _blinkTimer = 0;
        _blinkCount++;
        _blinkDelay = (_random.nextDouble() * 7000).ceilToDouble();
      }
    } else {
      if (_blinkTimer >= _blinkDelay && _blinkCount < _maxBlinkCount) {
        _isBlinking = true;
        _blinkTimer = 0;
      }
    }
  }

  void _updateRunning(double deltaTime) {
    _runTimer += deltaTime;
    if (_runTimer >= _runFrameRate) {
      _currentRunFrame = (_currentRunFrame + 1) % 2;
      _runTimer = 0;
    }
  }

  void _updateDucking(double deltaTime) {
    _runTimer += deltaTime;
    if (_runTimer >= _duckFrameRate) {
      _currentRunFrame = (_currentRunFrame + 1) % 2;
      _runTimer = 0;
    }
  }

  void _updateJumping(double framesElapsed) {
    if (speedDrop) {
      yPos += (jumpVelocity * GameConstants.speedDropCoefficient * framesElapsed)
          .roundToDouble();
    } else {
      yPos += (jumpVelocity * framesElapsed).roundToDouble();
    }
    jumpVelocity += TRexConfig.gravity * framesElapsed;

    // Reached minimum height – allow early termination.
    // In the original Chrome game, minJumpHeight is precomputed as
    // groundYPos - config.minJumpHeight (an absolute y position).
    if (yPos < TRexConfig.groundYPos - TRexConfig.minJumpHeight ||
        speedDrop) {
      reachedMinHeight = true;
    }

    // Reached max height – trigger descent by calling endJump().
    // In the original Chrome game, maxJumpHeight is compared directly
    // as an absolute y position (yPos < config.maxJumpHeight), and
    // endJump() is called (not a position clamp).
    if (yPos < TRexConfig.maxJumpHeight || speedDrop) {
      endJump();
    }

    // Back on the ground.
    if (yPos >= TRexConfig.groundYPos) {
      yPos = TRexConfig.groundYPos;
      jumpVelocity = 0;
      jumping = false;
      reachedMinHeight = false;
      speedDrop = false;

      // If a duck was requested while airborne, duck immediately on landing.
      if (duckQueued) {
        duckQueued = false;
        ducking = true;
        status = TRexStatus.ducking;
      } else {
        status = TRexStatus.running;
      }
    }
  }

  /// Called during the intro phase to slide the T-Rex on-screen.
  void updateIntro(double deltaTime, double speed) {
    _introTimer += deltaTime;
    if (playingIntro) {
      // Slide from left to startXPos.
      xPos += (speed * (deltaTime / GameConstants.msPerFrame)).roundToDouble();
      if (xPos >= TRexConfig.startXPos) {
        xPos = TRexConfig.startXPos;
        playingIntro = false;
        status = TRexStatus.running;
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  JUMP
  // ──────────────────────────────────────────────────────────────────────

  void startJump(double speed) {
    if (status == TRexStatus.crashed) return;
    if (status == TRexStatus.jumping || jumping) return;

    status = TRexStatus.jumping;
    jumping = true;
    reachedMinHeight = false;
    speedDrop = false;

    jumpVelocity = TRexConfig.initialJumpVelocity - (speed / 10);
    jumpCount++;
  }

  void endJump() {
    if (reachedMinHeight && jumpVelocity < TRexConfig.dropVelocity) {
      jumpVelocity = TRexConfig.dropVelocity;
    }
  }

  void setSpeedDrop() {
    speedDrop = true;
    jumpVelocity = 1;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  DUCK
  // ──────────────────────────────────────────────────────────────────────

  void setDuck(bool isDucking) {
    if (status == TRexStatus.crashed) return;

    if (isDucking && status == TRexStatus.jumping) {
      // Pressing down while jumping triggers speed-drop and queues ducking
      // so the dino ducks immediately on landing if still held.
      setSpeedDrop();
      duckQueued = true;
      return;
    }

    // Clear the queued duck when the input is released (even mid-air).
    if (!isDucking) {
      duckQueued = false;
    }

    if (isDucking && status != TRexStatus.jumping) {
      ducking = true;
      status = TRexStatus.ducking;
      // yPos stays at groundYPos — the ducking sprite is drawn
      // offset within the same 47px-tall frame as standing.
    } else if (!isDucking && status == TRexStatus.ducking) {
      ducking = false;
      status = TRexStatus.running;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  RESET
  // ──────────────────────────────────────────────────────────────────────

  void reset() {
    xPos = TRexConfig.startXPos;
    yPos = TRexConfig.groundYPos;
    jumpVelocity = 0;
    jumping = false;
    ducking = false;
    reachedMinHeight = false;
    speedDrop = false;
    jumpCount = 0;
    duckQueued = false;
    status = TRexStatus.waiting;
    playingIntro = false;

    _blinkCount = 0;
    _blinkTimer = 0;
    _blinkDelay = 0;
    _isBlinking = false;
    _introTimer = 0;

    _runTimer = 0;
    _currentRunFrame = 0;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  DRAW
  // ──────────────────────────────────────────────────────────────────────

  void draw(Canvas canvas, Size size, bool nightMode, SpriteSheet sprites) {
    switch (status) {
      case TRexStatus.waiting:
        if (_isBlinking) {
          sprites.drawTRexStand(canvas, xPos, yPos, nightMode: nightMode);
        } else {
          sprites.drawTRexWaiting(canvas, xPos, yPos, nightMode: nightMode);
        }
        break;
      case TRexStatus.running:
        sprites.drawTRexRun(canvas, xPos, yPos, _currentRunFrame,
            nightMode: nightMode);
        break;
      case TRexStatus.jumping:
        sprites.drawTRexStand(canvas, xPos, yPos, nightMode: nightMode);
        break;
      case TRexStatus.ducking:
        sprites.drawTRexDuck(canvas, xPos, yPos, _currentRunFrame,
            nightMode: nightMode);
        break;
      case TRexStatus.crashed:
        sprites.drawTRexCrashed(canvas, xPos, yPos, nightMode: nightMode);
        break;
    }
  }
}
