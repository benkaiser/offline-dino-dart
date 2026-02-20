import 'dart:math';
import 'dart:ui';

import 'constants.dart';
import 'sprites.dart';

/// A single obstacle instance in the game world.
///
/// Can represent a small cactus, large cactus, or pterodactyl.  Drawn using
/// the Chrome Dino sprite sheet via [SpriteSheet].
class Obstacle {
  final ObstacleConfig typeConfig;
  final double canvasWidth;
  final double gapCoefficient;
  final Random _random = Random();

  // ── Position & sizing ───────────────────────────────────────────────────
  double xPos;
  double yPos = 0;
  int size = 1; // 1-3 for cacti groups, always 1 for pterodactyl
  double gap = 0;
  bool followingObstacleCreated = false;
  bool remove = false;

  /// Effective width accounting for group size.
  double get width => typeConfig.width * size;

  /// Effective height.
  double get height => typeConfig.height;

  // ── Pterodactyl flap animation ──────────────────────────────────────────
  int _currentFrame = 0;
  double _flapTimer = 0;
  static const double _flapFrameRate = 167; // ms per frame (~6 fps)

  // ──────────────────────────────────────────────────────────────────────
  //  CONSTRUCTOR
  // ──────────────────────────────────────────────────────────────────────

  Obstacle({
    required this.typeConfig,
    required this.canvasWidth,
    required this.gapCoefficient,
    required double speed,
    int? obstacleSize,
  }) : xPos = canvasWidth {
    // Determine group size (cacti only).
    if (typeConfig.type != ObstacleType.pterodactyl) {
      size = (obstacleSize ?? _randomSize()).clamp(1, GameConstants.maxObstacleLength);
    } else {
      size = 1;
    }

    // Y position.
    if (typeConfig.type == ObstacleType.pterodactyl) {
      final heights = typeConfig.yPosList ?? [typeConfig.yPos];
      yPos = heights[_random.nextInt(heights.length)];
    } else {
      yPos = typeConfig.yPos;
    }

    // Calculate gap to next obstacle.
    _calculateGap(speed);
  }

  int _randomSize() {
    return _random.nextInt(GameConstants.maxObstacleLength) + 1;
  }

  void _calculateGap(double speed) {
    final double obstWidth = width;
    final double minGap =
        (obstWidth * speed + typeConfig.minGap * gapCoefficient).roundToDouble();
    final double maxGap = (minGap * GameConstants.maxGapCoefficient).roundToDouble();
    gap = _randomBetween(minGap, maxGap);
  }

  double _randomBetween(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  // ──────────────────────────────────────────────────────────────────────
  //  COLLISION BOXES
  // ──────────────────────────────────────────────────────────────────────

  /// Returns collision boxes adjusted for world position and group size.
  List<CollisionBox> getCollisionBoxes() {
    final List<CollisionBox> boxes = [];

    for (int i = 0; i < size; i++) {
      final double offsetX = i * typeConfig.width;
      for (final box in typeConfig.collisionBoxes) {
        boxes.add(CollisionBox(
          box.x + xPos + offsetX,
          box.y + yPos,
          box.width,
          box.height,
        ));
      }
    }

    return boxes;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  UPDATE
  // ──────────────────────────────────────────────────────────────────────

  /// Move the obstacle left.  [deltaTime] is in milliseconds, [speed] is
  /// the current game speed.
  void update(double deltaTime, double speed) {
    // Move left.
    final double increment = (speed * 60 / 1000 * deltaTime).floorToDouble();
    xPos -= increment;

    // Pterodactyl wing-flap animation.
    if (typeConfig.type == ObstacleType.pterodactyl) {
      _flapTimer += deltaTime;
      if (_flapTimer >= _flapFrameRate) {
        _currentFrame = (_currentFrame + 1) % typeConfig.numFrames;
        _flapTimer = 0;
      }
    }

    // Mark for removal when fully off-screen left.
    if (xPos + width <= 0) {
      remove = true;
    }
  }

  /// Returns true if any part of this obstacle is visible on screen.
  bool isVisible() {
    return xPos + width > 0;
  }

  // ──────────────────────────────────────────────────────────────────────
  //  DRAW
  // ──────────────────────────────────────────────────────────────────────

  void draw(Canvas canvas, Size canvasSize, SpriteSheet sprites, {bool nightMode = false}) {
    switch (typeConfig.type) {
      case ObstacleType.cactusSmall:
        sprites.drawSmallCactus(canvas, xPos, yPos, size, nightMode: nightMode);
        break;
      case ObstacleType.cactusLarge:
        sprites.drawLargeCactus(canvas, xPos, yPos, size, nightMode: nightMode);
        break;
      case ObstacleType.pterodactyl:
        sprites.drawPterodactyl(canvas, xPos, yPos, _currentFrame, nightMode: nightMode);
        break;
    }
  }
}
