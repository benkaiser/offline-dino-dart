import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Provides access to individual sprites from the Chrome Dino sprite sheet.
///
/// The sprite sheet is a single 1233x100 PNG at 1x (LDPI) resolution.
/// Call [load] once before drawing, then use the convenience methods
/// to blit individual sprites onto a [ui.Canvas].
class SpriteSheet {
  ui.Image? _image;

  /// Whether the sprite sheet image has finished loading.
  bool get isLoaded => _image != null;

  /// Load the sprite sheet from the asset bundle.
  Future<void> load() async {
    final data = await rootBundle.load('assets/100-offline-sprite.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _image = frame.image;
  }

  // ---------------------------------------------------------------------------
  // Sprite source rectangles
  // ---------------------------------------------------------------------------

  // T-Rex frames (44x47 unless noted, all at y=2)
  static const _trexStand = ui.Rect.fromLTWH(848, 2, 44, 47);
  static const _trexWaiting = ui.Rect.fromLTWH(892, 2, 44, 47);
  static const _trexRun1 = ui.Rect.fromLTWH(936, 2, 44, 47);
  static const _trexRun2 = ui.Rect.fromLTWH(980, 2, 44, 47);
  static const _trexCrashed = ui.Rect.fromLTWH(1068, 2, 44, 47);
  // Duck frames: 59px wide, sourced as 47px tall (same as standing) —
  // the original Chrome game reads 47px of height even for ducking,
  // with transparent padding below the 25px duck sprite.
  static const _trexDuck1 = ui.Rect.fromLTWH(1112, 2, 59, 47);
  static const _trexDuck2 = ui.Rect.fromLTWH(1171, 2, 59, 47);

  // Obstacles
  static const double _smallCactusX = 228;
  static const double _smallCactusY = 2;
  static const double _smallCactusW = 17;
  static const double _smallCactusH = 35;

  static const double _largeCactusX = 332;
  static const double _largeCactusY = 2;
  static const double _largeCactusW = 25;
  static const double _largeCactusH = 50;

  static const _ptero1 = ui.Rect.fromLTWH(134, 2, 46, 40);
  static const _ptero2 = ui.Rect.fromLTWH(180, 2, 46, 40);

  // Environment
  static const _cloud = ui.Rect.fromLTWH(86, 2, 46, 14);
  static const double _groundX = 2;
  static const double _groundY = 54;
  static const double _groundH = 12;

  // Moon: base position at (484, 2), each phase 20px wide, 40px tall
  static const double _moonBaseX = 484;
  static const double _moonY = 2;
  static const double _moonW = 20;
  static const double _moonH = 40;

  // Stars: two 9x9 star sprites stacked vertically at (645, 2)
  static const double _starX = 645;
  static const double _starY = 2;
  static const double _starSize = 9;

  // UI
  static const _gameOver = ui.Rect.fromLTWH(655, 15, 191, 11);
  static const _restart = ui.Rect.fromLTWH(254, 68, 36, 32); // retry arrow (frame 7)
  static const double _digitBaseX = 655;
  static const double _digitY = 2;
  static const double _digitW = 10;
  static const double _digitH = 13;
  static const _hi =
      ui.Rect.fromLTWH(755, 2, 20, 13); // "H" (10px) + "I" (10px)

  // ---------------------------------------------------------------------------
  // Generic draw
  // ---------------------------------------------------------------------------

  /// Draw a rectangular region of the sprite sheet onto [canvas].
  ///
  /// [src] is the source rectangle in sprite-sheet coordinates.
  /// [dst] is the destination rectangle on the canvas.
  /// When [nightMode] is true, colours are inverted via a colour-filter matrix.
  void draw(
    ui.Canvas canvas,
    ui.Rect src,
    ui.Rect dst, {
    bool nightMode = false,
  }) {
    if (_image == null) return;

    final paint = ui.Paint()..isAntiAlias = false;
    if (nightMode) {
      paint.colorFilter = const ui.ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]);
    }

    canvas.drawImageRect(_image!, src, dst, paint);
  }

  // ---------------------------------------------------------------------------
  // T-Rex convenience methods
  // ---------------------------------------------------------------------------

  /// Draw the standing / jumping T-Rex at ([x], [y]).
  void drawTRexStand(
    ui.Canvas canvas,
    double x,
    double y, {
    bool nightMode = false,
  }) {
    draw(
      canvas,
      _trexStand,
      ui.Rect.fromLTWH(x, y, _trexStand.width, _trexStand.height),
      nightMode: nightMode,
    );
  }

  /// Draw the waiting (eyes-open, blinking idle) T-Rex at ([x], [y]).
  void drawTRexWaiting(
    ui.Canvas canvas,
    double x,
    double y, {
    bool nightMode = false,
  }) {
    draw(
      canvas,
      _trexWaiting,
      ui.Rect.fromLTWH(x, y, _trexWaiting.width, _trexWaiting.height),
      nightMode: nightMode,
    );
  }

  /// Draw a running T-Rex animation frame (0 or 1) at ([x], [y]).
  void drawTRexRun(
    ui.Canvas canvas,
    double x,
    double y,
    int frame, {
    bool nightMode = false,
  }) {
    final src = frame == 0 ? _trexRun1 : _trexRun2;
    draw(
      canvas,
      src,
      ui.Rect.fromLTWH(x, y, src.width, src.height),
      nightMode: nightMode,
    );
  }

  /// Draw a ducking T-Rex animation frame (0 or 1) at ([x], [y]).
  ///
  /// The source rect is 59x47 (same height as standing). The duck art
  /// occupies the top ~25px with transparent padding below, matching the
  /// original Chrome game which always sources 47px of height.
  void drawTRexDuck(
    ui.Canvas canvas,
    double x,
    double y,
    int frame, {
    bool nightMode = false,
  }) {
    final src = frame == 0 ? _trexDuck1 : _trexDuck2;
    draw(
      canvas,
      src,
      ui.Rect.fromLTWH(x, y, src.width, src.height),
      nightMode: nightMode,
    );
  }

  /// Draw the crashed T-Rex at ([x], [y]).
  void drawTRexCrashed(
    ui.Canvas canvas,
    double x,
    double y, {
    bool nightMode = false,
  }) {
    draw(
      canvas,
      _trexCrashed,
      ui.Rect.fromLTWH(x, y, _trexCrashed.width, _trexCrashed.height),
      nightMode: nightMode,
    );
  }

  // ---------------------------------------------------------------------------
  // Obstacles
  // ---------------------------------------------------------------------------

  /// Draw [count] small cacti (1-3) side by side starting at ([x], [y]).
  void drawSmallCactus(
    ui.Canvas canvas,
    double x,
    double y,
    int count, {
    bool nightMode = false,
  }) {
    assert(count >= 1 && count <= 3);
    final totalW = _smallCactusW * count;
    final src = ui.Rect.fromLTWH(
      _smallCactusX,
      _smallCactusY,
      totalW,
      _smallCactusH,
    );
    draw(
      canvas,
      src,
      ui.Rect.fromLTWH(x, y, totalW, _smallCactusH),
      nightMode: nightMode,
    );
  }

  /// Draw [count] large cacti (1-3) side by side starting at ([x], [y]).
  void drawLargeCactus(
    ui.Canvas canvas,
    double x,
    double y,
    int count, {
    bool nightMode = false,
  }) {
    assert(count >= 1 && count <= 3);
    final totalW = _largeCactusW * count;
    final src = ui.Rect.fromLTWH(
      _largeCactusX,
      _largeCactusY,
      totalW,
      _largeCactusH,
    );
    draw(
      canvas,
      src,
      ui.Rect.fromLTWH(x, y, totalW, _largeCactusH),
      nightMode: nightMode,
    );
  }

  /// Draw a pterodactyl animation frame (0 or 1) at ([x], [y]).
  void drawPterodactyl(
    ui.Canvas canvas,
    double x,
    double y,
    int frame, {
    bool nightMode = false,
  }) {
    final src = frame == 0 ? _ptero1 : _ptero2;
    draw(
      canvas,
      src,
      ui.Rect.fromLTWH(x, y, src.width, src.height),
      nightMode: nightMode,
    );
  }

  // ---------------------------------------------------------------------------
  // Environment
  // ---------------------------------------------------------------------------

  /// Draw a cloud at ([x], [y]).
  void drawCloud(
    ui.Canvas canvas,
    double x,
    double y, {
    bool nightMode = false,
  }) {
    draw(
      canvas,
      _cloud,
      ui.Rect.fromLTWH(x, y, _cloud.width, _cloud.height),
      nightMode: nightMode,
    );
  }

  /// Draw the moon at ([x], [y]) with the given [phaseOffset] and [opacity].
  ///
  /// [phaseOffset] is the x-offset into the moon sprite strip (from
  /// [NightModeConfig.moonPhases]).
  /// Phase 3 (offset = 60) is full moon, drawn at double width (40px).
  void drawMoon(
    ui.Canvas canvas,
    double x,
    double y,
    int phaseOffset,
    double opacity,
  ) {
    if (_image == null || opacity <= 0) return;

    final bool isFullMoon = (phaseOffset == 60);
    final double srcW = isFullMoon ? _moonW * 2 : _moonW;
    final src = ui.Rect.fromLTWH(
      _moonBaseX + phaseOffset,
      _moonY,
      srcW,
      _moonH,
    );
    final dst = ui.Rect.fromLTWH(x, y, srcW, _moonH);

    final paint = ui.Paint()
      ..isAntiAlias = false
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(_image!, src, dst, paint);
  }

  /// Draw a star at ([x], [y]) with the given [starIndex] (0 or 1) and
  /// [opacity].
  void drawStar(
    ui.Canvas canvas,
    double x,
    double y,
    int starIndex,
    double opacity,
  ) {
    if (_image == null || opacity <= 0) return;

    final src = ui.Rect.fromLTWH(
      _starX,
      _starY + starIndex * _starSize,
      _starSize,
      _starSize,
    );
    final dst = ui.Rect.fromLTWH(x, y, _starSize, _starSize);

    final paint = ui.Paint()
      ..isAntiAlias = false
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(_image!, src, dst, paint);
  }

  /// Draw a section of the ground line at ([x], [y]).
  ///
  /// [srcX] is the horizontal offset into the ground strip (for scrolling).
  /// [width] is how many pixels wide to draw.
  void drawGround(
    ui.Canvas canvas,
    double x,
    double y,
    double srcX,
    double width, {
    bool nightMode = false,
  }) {
    final src = ui.Rect.fromLTWH(_groundX + srcX, _groundY, width, _groundH);
    draw(
      canvas,
      src,
      ui.Rect.fromLTWH(x, y, width, _groundH),
      nightMode: nightMode,
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  /// Draw the "GAME OVER" text centred at ([x], [y]).
  void drawGameOver(
    ui.Canvas canvas,
    double x,
    double y, {
    bool nightMode = false,
  }) {
    draw(
      canvas,
      _gameOver,
      ui.Rect.fromLTWH(x, y, _gameOver.width, _gameOver.height),
      nightMode: nightMode,
    );
  }

  /// Draw the restart button at ([x], [y]).
  void drawRestart(
    ui.Canvas canvas,
    double x,
    double y, {
    bool nightMode = false,
  }) {
    draw(
      canvas,
      _restart,
      ui.Rect.fromLTWH(x, y, _restart.width, _restart.height),
      nightMode: nightMode,
    );
  }

  /// Draw a single score digit (0-9) at ([x], [y]).
  void drawDigit(
    ui.Canvas canvas,
    double x,
    double y,
    int digit, {
    bool nightMode = false,
  }) {
    assert(digit >= 0 && digit <= 9);
    final src = ui.Rect.fromLTWH(
      _digitBaseX + _digitW * digit,
      _digitY,
      _digitW,
      _digitH,
    );
    draw(
      canvas,
      src,
      ui.Rect.fromLTWH(x, y, _digitW, _digitH),
      nightMode: nightMode,
    );
  }

  /// Draw the "HI" label at ([x], [y]).
  void drawHI(
    ui.Canvas canvas,
    double x,
    double y, {
    bool nightMode = false,
  }) {
    draw(
      canvas,
      _hi,
      ui.Rect.fromLTWH(x, y, _hi.width, _hi.height),
      nightMode: nightMode,
    );
  }
}
