import 'dart:math';
import 'dart:ui';

import 'constants.dart';
import 'obstacle.dart';
import 'sprites.dart';

// ══════════════════════════════════════════════════════════════════════════
//  NIGHT MODE (moon + stars)
// ══════════════════════════════════════════════════════════════════════════

class _Star {
  double x;
  double y;
  final int spriteIndex; // 0 or 1

  _Star({required this.x, required this.y, required this.spriteIndex});
}

/// Manages the moon and stars shown during night mode.
class NightMode {
  final double containerWidth;
  final Random _random;

  double _opacity = 0;
  double _moonXPos = 0;
  double _moonYPos = 30;
  int _currentPhase = 0;
  final List<_Star> _stars = [];
  bool _activated = false; // whether night mode is currently desired

  NightMode({required this.containerWidth, Random? random})
      : _random = random ?? Random() {
    _placeStars();
  }

  double get opacity => _opacity;

  /// Place [NightModeConfig.numStars] stars at random positions.
  void _placeStars() {
    _stars.clear();
    final int numStars = NightModeConfig.numStars;
    final double segmentWidth = containerWidth / numStars;
    for (int i = 0; i < numStars; i++) {
      _stars.add(_Star(
        x: segmentWidth * i + _random.nextDouble() * segmentWidth,
        y: _random.nextDouble() * NightModeConfig.starMaxY,
        spriteIndex: i % 2,
      ));
    }
  }

  void update(double deltaTime, bool showNightMode) {
    final double framesElapsed = deltaTime / GameConstants.msPerFrame;

    // Fade in / out.
    if (showNightMode) {
      if (!_activated) {
        _activated = true;
        // Advance moon phase each time night mode freshly activates.
        _currentPhase =
            (_currentPhase + 1) % NightModeConfig.moonPhases.length;
      }
      _opacity = (_opacity + NightModeConfig.fadeSpeed * framesElapsed)
          .clamp(0.0, 1.0);
    } else {
      if (_activated && _opacity <= 0) {
        _activated = false;
        // Re-randomize stars when fully faded out.
        _placeStars();
      }
      _opacity = (_opacity - NightModeConfig.fadeSpeed * framesElapsed)
          .clamp(0.0, 1.0);
    }

    if (_opacity <= 0) return;

    // Scroll moon.
    _moonXPos -= NightModeConfig.moonSpeed * framesElapsed;
    if (_moonXPos < -NightModeConfig.moonWidth) {
      _moonXPos = containerWidth;
    }

    // Scroll stars.
    for (final star in _stars) {
      star.x -= NightModeConfig.starSpeed * framesElapsed;
      if (star.x < -NightModeConfig.starSize) {
        star.x = containerWidth;
      }
    }
  }

  void draw(Canvas canvas, SpriteSheet sprites) {
    if (_opacity <= 0) return;

    final int phaseOffset = NightModeConfig.moonPhases[_currentPhase];
    sprites.drawMoon(canvas, _moonXPos, _moonYPos, phaseOffset, _opacity);

    for (final star in _stars) {
      sprites.drawStar(canvas, star.x, star.y, star.spriteIndex, _opacity);
    }
  }

  void reset() {
    _opacity = 0;
    _moonXPos = 0;
    _moonYPos = 30;
    _currentPhase = 0;
    _activated = false;
    _placeStars();
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  CLOUD
// ══════════════════════════════════════════════════════════════════════════

/// A cloud drawn from the sprite sheet.
class Cloud {
  double xPos;
  double yPos;
  double gap;
  bool remove = false;

  static const double _width = CloudConfig.width; // 46

  Cloud({required this.xPos, required this.yPos, required this.gap});

  void update(double deltaTime, double speed) {
    final cloudSpeed = GameConstants.bgCloudSpeed / 1000 * deltaTime * speed;
    xPos -= cloudSpeed.ceilToDouble();
    if (xPos + _width < 0) {
      remove = true;
    }
  }

  void draw(Canvas canvas, SpriteSheet sprites, {bool nightMode = false}) {
    sprites.drawCloud(canvas, xPos, yPos, nightMode: nightMode);
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  HORIZON LINE
// ══════════════════════════════════════════════════════════════════════════

/// Two side-by-side ground segments that scroll endlessly to the left.
class HorizonLine {
  double _sourceXPos0 = 0;
  double _sourceXPos1 = 0;
  final double _segmentWidth;

  static const double _yPos = GameConstants.groundYPos; // 127

  HorizonLine(double canvasWidth)
      : _segmentWidth = 600 {
    _sourceXPos0 = 0;
    _sourceXPos1 = _segmentWidth;
  }

  void update(double deltaTime, double speed) {
    final double increment = (speed * 60 / 1000 * deltaTime).floorToDouble();

    _sourceXPos0 -= increment;
    _sourceXPos1 -= increment;

    // Wrap segments when they scroll off-screen.
    if (_sourceXPos0 + _segmentWidth <= 0) {
      _sourceXPos0 = _sourceXPos1 + _segmentWidth;
    }
    if (_sourceXPos1 + _segmentWidth <= 0) {
      _sourceXPos1 = _sourceXPos0 + _segmentWidth;
    }
  }

  void draw(Canvas canvas, SpriteSheet sprites, {bool nightMode = false}) {
    sprites.drawGround(canvas, _sourceXPos0, _yPos, 0, 600,
        nightMode: nightMode);
    sprites.drawGround(canvas, _sourceXPos1, _yPos, 0, 600,
        nightMode: nightMode);
  }

  void reset() {
    _sourceXPos0 = 0;
    _sourceXPos1 = _segmentWidth;
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  HORIZON
// ══════════════════════════════════════════════════════════════════════════

/// Manages the scrolling ground line, clouds, and obstacles.
class Horizon {
  final double canvasWidth;
  final Random _random = Random();

  late HorizonLine _horizonLine;
  final List<Cloud> _clouds = [];
  final List<Obstacle> obstacles = [];
  late NightMode nightMode;

  // Obstacle generation state.
  ObstacleType? _lastObstacleType;
  int _duplicateObstacleCount = 0;
  double _runTime = 0; // total ms elapsed, used for clearTime

  Horizon({required this.canvasWidth}) {
    _horizonLine = HorizonLine(canvasWidth);
    nightMode = NightMode(containerWidth: canvasWidth, random: _random);
    _addInitialClouds();
  }

  // ──────────────────────────────────────────────────────────────────────
  //  UPDATE
  // ──────────────────────────────────────────────────────────────────────

  /// [deltaTime] in ms, [currentSpeed] is the game speed, [hasObstacles]
  /// controls whether obstacles should be spawned, [showNightMode] is
  /// reserved for future night mode styling.
  void update(double deltaTime, double currentSpeed, bool hasObstacles,
      bool showNightMode) {
    _runTime += deltaTime;

    // Ground line.
    _horizonLine.update(deltaTime, currentSpeed);

    // Clouds.
    _updateClouds(deltaTime, currentSpeed);

    // Night mode (moon + stars).
    nightMode.update(deltaTime, showNightMode);

    // Obstacles.
    if (hasObstacles) {
      _updateObstacles(deltaTime, currentSpeed);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  DRAW
  // ──────────────────────────────────────────────────────────────────────

  void draw(Canvas canvas, Size size, SpriteSheet sprites, bool nightMode) {
    // Night sky (moon + stars, behind everything).
    this.nightMode.draw(canvas, sprites);

    // Clouds (behind everything else).
    for (final cloud in _clouds) {
      cloud.draw(canvas, sprites, nightMode: nightMode);
    }

    // Ground line.
    _horizonLine.draw(canvas, sprites, nightMode: nightMode);

    // Obstacles.
    for (final obs in obstacles) {
      obs.draw(canvas, size, sprites, nightMode: nightMode);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  //  CLOUDS
  // ──────────────────────────────────────────────────────────────────────

  void _addInitialClouds() {
    // Seed a few clouds at random positions so the sky isn't empty at start.
    final int count = 1 + _random.nextInt(3); // 1-3 starting clouds
    for (int i = 0; i < count; i++) {
      _clouds.add(Cloud(
        xPos: _random.nextDouble() * canvasWidth,
        yPos: _randomCloudY(),
        gap: _randomCloudGap(),
      ));
    }
  }

  void _updateClouds(double deltaTime, double speed) {
    // Update existing clouds.
    for (final cloud in _clouds) {
      cloud.update(deltaTime, speed);
    }

    // Remove off-screen clouds.
    _clouds.removeWhere((c) => c.remove);

    // Add new clouds.
    if (_clouds.length < GameConstants.maxClouds) {
      if (_clouds.isEmpty) {
        _addCloud();
      } else {
        final Cloud last = _clouds.last;
        final double distFromRight = canvasWidth - (last.xPos + CloudConfig.width);
        if (distFromRight > last.gap &&
            GameConstants.cloudFrequency > _random.nextDouble()) {
          _addCloud();
        }
      }
    }
  }

  void _addCloud() {
    _clouds.add(Cloud(
      xPos: canvasWidth,
      yPos: _randomCloudY(),
      gap: _randomCloudGap(),
    ));
  }

  double _randomCloudY() {
    return CloudConfig.maxSkyLevel +
        _random.nextDouble() * (CloudConfig.minSkyLevel - CloudConfig.maxSkyLevel);
  }

  double _randomCloudGap() {
    return CloudConfig.minCloudGap +
        _random.nextDouble() * (CloudConfig.maxCloudGap - CloudConfig.minCloudGap);
  }

  // ──────────────────────────────────────────────────────────────────────
  //  OBSTACLES
  // ──────────────────────────────────────────────────────────────────────

  void _updateObstacles(double deltaTime, double currentSpeed) {
    // Update existing obstacles.
    for (final obs in obstacles) {
      obs.update(deltaTime, currentSpeed);
    }

    // Remove off-screen obstacles.
    obstacles.removeWhere((o) => o.remove);

    // Wait for clear time before spawning first obstacles.
    if (_runTime < GameConstants.clearTime) return;

    // Spawn new obstacle if needed.
    if (obstacles.isEmpty) {
      _addObstacle(currentSpeed);
    } else {
      final Obstacle last = obstacles.last;
      if (last.isVisible() &&
          (last.xPos + last.width + last.gap) < canvasWidth) {
        _addObstacle(currentSpeed);
      }
    }
  }

  void _addObstacle(double currentSpeed) {
    final ObstacleConfig config = _selectObstacleType(currentSpeed);

    // Determine group size for cacti.
    int obstacleSize = 1;
    if (config.type != ObstacleType.pterodactyl) {
      if (config.multipleSpeed <= currentSpeed) {
        obstacleSize = 1 + _random.nextInt(GameConstants.maxObstacleLength);
      }
    }

    obstacles.add(Obstacle(
      typeConfig: config,
      canvasWidth: canvasWidth,
      gapCoefficient: GameConstants.gapCoefficient,
      speed: currentSpeed,
      obstacleSize: obstacleSize,
    ));
  }

  /// Select a random obstacle type, preventing too many consecutive
  /// duplicates and gating pterodactyl behind a minimum speed.
  ObstacleConfig _selectObstacleType(double currentSpeed) {
    // Filter configs by minimum speed.
    final available = obstacleConfigs
        .where((c) => c.minSpeed <= currentSpeed)
        .toList();

    // Pick a random type.
    ObstacleConfig chosen = available[_random.nextInt(available.length)];

    // Prevent more than maxObstacleDuplication consecutive same types.
    if (chosen.type == _lastObstacleType) {
      _duplicateObstacleCount++;
      if (_duplicateObstacleCount >= GameConstants.maxObstacleDuplication) {
        // Force a different type.
        final others = available.where((c) => c.type != _lastObstacleType).toList();
        if (others.isNotEmpty) {
          chosen = others[_random.nextInt(others.length)];
          _duplicateObstacleCount = 0;
        }
      }
    } else {
      _duplicateObstacleCount = 0;
    }

    _lastObstacleType = chosen.type;
    return chosen;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  RESET
  // ──────────────────────────────────────────────────────────────────────

  void reset() {
    obstacles.clear();
    _clouds.clear();
    _horizonLine.reset();
    nightMode.reset();
    _lastObstacleType = null;
    _duplicateObstacleCount = 0;
    _runTime = 0;
    _addInitialClouds();
  }
}
