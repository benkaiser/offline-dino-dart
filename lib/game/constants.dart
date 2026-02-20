// Game constants matching the Chrome Dino game.

class GameConstants {
  // Canvas / world dimensions (logical pixels)
  static const double worldWidth = 600;
  static const double worldHeight = 150;

  // Frame rate
  static const double fps = 60;
  static const double msPerFrame = 1000.0 / fps;

  // Game config
  static const double initialSpeed = 6.0;
  static const double maxSpeed = 13.0;
  static const double acceleration = 0.001;
  static const double bgCloudSpeed = 0.2;
  static const double bottomPad = 10.0;
  static const double clearTime = 3000.0; // ms before obstacles appear
  static const double cloudFrequency = 0.5;
  static const double gapCoefficient = 0.6;
  static const double maxGapCoefficient = 1.5;
  static const int maxClouds = 6;
  static const int maxObstacleLength = 3;
  static const int maxObstacleDuplication = 2;
  static const double invertDistance = 700;
  static const double invertFadeDuration = 12000;
  static const double gameOverClearTime = 750;
  static const double speedDropCoefficient = 3.0;

  // Score
  static const double scoreCoefficient = 0.025;
  static const int achievementDistance = 100;
  static const double flashDuration = 250;
  static const int flashIterations = 3;

  // Ground
  static const double groundYPos = 127.0;
  static const double horizonHeight = 12.0;
}

class TRexConfig {
  static const double dropVelocity = -5.0;
  static const double height = 47.0;
  static const double heightDuck = 25.0;
  static const double width = 44.0;
  static const double widthDuck = 59.0;
  static const double startXPos = 50.0;
  static const double introDuration = 1500.0;

  // Jump physics
  static const double gravity = 0.6;
  static const double maxJumpHeight = 30.0;
  static const double minJumpHeight = 30.0;
  static const double initialJumpVelocity = -10.0;

  // Ground Y
  static const double groundYPos =
      GameConstants.worldHeight - height - GameConstants.bottomPad; // 93
}

/// Collision box: relative position and size within a sprite.
class CollisionBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const CollisionBox(this.x, this.y, this.width, this.height);

  CollisionBox copyWith({double? x, double? y, double? width, double? height}) {
    return CollisionBox(
      x ?? this.x,
      y ?? this.y,
      width ?? this.width,
      height ?? this.height,
    );
  }
}

/// T-Rex collision boxes for running pose.
const List<CollisionBox> trexRunningCollisionBoxes = [
  CollisionBox(22, 0, 17, 16),
  CollisionBox(1, 18, 30, 9),
  CollisionBox(10, 35, 14, 8),
  CollisionBox(1, 24, 29, 5),
  CollisionBox(5, 30, 21, 4),
  CollisionBox(9, 34, 15, 4),
];

/// T-Rex collision boxes for ducking pose.
const List<CollisionBox> trexDuckingCollisionBoxes = [
  CollisionBox(1, 18, 55, 25),
];

/// Obstacle type configurations.
enum ObstacleType { cactusSmall, cactusLarge, pterodactyl }

class ObstacleConfig {
  final ObstacleType type;
  final double width;
  final double height;
  final double yPos;
  final List<double>? yPosList; // For pterodactyl multiple heights
  final double multipleSpeed;
  final double minGap;
  final double minSpeed;
  final int numFrames;
  final double frameRate;
  final double speedOffset;
  final List<CollisionBox> collisionBoxes;

  const ObstacleConfig({
    required this.type,
    required this.width,
    required this.height,
    required this.yPos,
    this.yPosList,
    required this.multipleSpeed,
    required this.minGap,
    required this.minSpeed,
    this.numFrames = 1,
    this.frameRate = 0,
    this.speedOffset = 0,
    required this.collisionBoxes,
  });
}

const ObstacleConfig cactusSmallConfig = ObstacleConfig(
  type: ObstacleType.cactusSmall,
  width: 17,
  height: 35,
  yPos: 105,
  multipleSpeed: 4,
  minGap: 120,
  minSpeed: 0,
  collisionBoxes: [
    CollisionBox(0, 7, 5, 27),
    CollisionBox(4, 0, 6, 34),
    CollisionBox(10, 4, 7, 14),
  ],
);

const ObstacleConfig cactusLargeConfig = ObstacleConfig(
  type: ObstacleType.cactusLarge,
  width: 25,
  height: 50,
  yPos: 90,
  multipleSpeed: 7,
  minGap: 120,
  minSpeed: 0,
  collisionBoxes: [
    CollisionBox(0, 12, 7, 38),
    CollisionBox(8, 0, 7, 49),
    CollisionBox(13, 10, 10, 38),
  ],
);

const ObstacleConfig pterodactylConfig = ObstacleConfig(
  type: ObstacleType.pterodactyl,
  width: 46,
  height: 40,
  yPosList: [100, 75, 50],
  yPos: 100,
  multipleSpeed: 999,
  minGap: 150,
  minSpeed: 8.5,
  numFrames: 2,
  frameRate: 1000.0 / 6.0,
  speedOffset: 0.8,
  collisionBoxes: [
    CollisionBox(15, 15, 16, 5),
    CollisionBox(18, 21, 24, 6),
    CollisionBox(2, 14, 4, 3),
    CollisionBox(6, 10, 4, 7),
    CollisionBox(10, 8, 6, 9),
  ],
);

const List<ObstacleConfig> obstacleConfigs = [
  cactusSmallConfig,
  cactusLargeConfig,
  pterodactylConfig,
];

/// Night mode config (moon + stars)
class NightModeConfig {
  static const double fadeSpeed = 0.035; // alpha per frame
  static const double moonSpeed = 0.25; // px per frame
  static const double starSpeed = 0.3; // px per frame
  static const int numStars = 2;
  static const double starSize = 9;
  static const double starMaxY = 70;
  static const double moonWidth = 20;
  static const double moonHeight = 40;

  /// Moon phase x-offsets added to the base sprite position.
  /// 7 phases cycling through new → full → crescent.
  static const List<int> moonPhases = [140, 120, 100, 60, 40, 20, 0];
}

/// Cloud config
class CloudConfig {
  static const double width = 46;
  static const double height = 14;
  static const double minCloudGap = 100;
  static const double maxCloudGap = 400;
  static const double maxSkyLevel = 30;
  static const double minSkyLevel = 71;
}
