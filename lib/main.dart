import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'game/game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DinoGameScreen(),
    ),
  );
}

class DinoGameScreen extends StatefulWidget {
  const DinoGameScreen({super.key});

  @override
  State<DinoGameScreen> createState() => _DinoGameScreenState();
}

class _DinoGameScreenState extends State<DinoGameScreen>
    with SingleTickerProviderStateMixin {
  late final DinoGame game;
  late final Ticker _ticker;
  final FocusNode _focusNode = FocusNode();
  final _repaintNotifier = _GameRepaintNotifier();

  Duration _previousTime = Duration.zero;
  double _panStartY = 0;
  bool _isDucking = false;
  bool _jumpedThisGesture = false;

  @override
  void initState() {
    super.initState();
    game = DinoGame(canvasWidth: 600);
    game.init(); // load sprite sheet asynchronously
    _ticker = createTicker(_onTick);
    _ticker.start();
    _focusNode.requestFocus();
  }

  void _onTick(Duration elapsed) {
    final double deltaTime;
    if (_previousTime == Duration.zero) {
      deltaTime = 16.0; // ~60fps first frame
    } else {
      deltaTime = (elapsed - _previousTime).inMicroseconds / 1000.0;
    }
    _previousTime = elapsed;

    // Clamp to avoid huge jumps (e.g. after tab switch)
    final clampedDt = deltaTime.clamp(0.0, 50.0);
    game.update(clampedDt);
    _repaintNotifier.notify();
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp) {
        game.onAction();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        game.onDuck(true);
      }
    } else if (event is KeyUpEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp) {
        game.onActionEnd();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        game.onDuck(false);
      }
    }
  }

  // ── Touch / pan gesture handlers ────────────────────────────────────
  // We use a single pan recogniser instead of separate tap + vertical-drag
  // recognisers. This avoids the gesture-arena conflict where Flutter has
  // to decide which recogniser wins, causing lag or missed inputs.
  //
  // • Touch-down → jump (immediately).
  // • Drag downward > 20px → switch to ducking (cancels the jump intent).
  // • Lift finger → end duck / end jump.

  void _onPanDown(DragDownDetails details) {
    _panStartY = details.globalPosition.dy;
    _isDucking = false;
    _jumpedThisGesture = true;
    game.onAction(); // jump immediately on touch
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final dy = details.globalPosition.dy - _panStartY;
    if (dy > 20 && !_isDucking) {
      _isDucking = true;
      _jumpedThisGesture = false;
      game.onDuck(true);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDucking) {
      _isDucking = false;
      game.onDuck(false);
    }
    if (_jumpedThisGesture) {
      game.onActionEnd();
      _jumpedThisGesture = false;
    }
  }

  void _onPanCancel() {
    if (_isDucking) {
      _isDucking = false;
      game.onDuck(false);
    }
    if (_jumpedThisGesture) {
      game.onActionEnd();
      _jumpedThisGesture = false;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    _repaintNotifier.dispose();
    game.sounds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sync the scaffold background with the game's night mode state.
    final bgColor = game.showNightMode
        ? const Color(0xFF303030)
        : const Color(0xFFF7F7F7);
    return Scaffold(
      backgroundColor: bgColor,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: _onPanDown,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: SizedBox.expand(
            child: CustomPaint(
              painter: DinoGamePainter(
                game: game,
                repaint: _repaintNotifier,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameRepaintNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

class DinoGamePainter extends CustomPainter {
  final DinoGame game;

  DinoGamePainter({
    required this.game,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const double _logicalWidth = 600.0;
  static const double _logicalHeight = 150.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Fill the entire screen with the game background colour so
    // areas outside the logical canvas match during night mode.
    final Color bgColor = game.showNightMode
        ? const Color(0xFF303030)
        : const Color(0xFFF7F7F7);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    final double scale = size.width / _logicalWidth;
    final double scaledHeight = _logicalHeight * scale;
    final double offsetY = (size.height - scaledHeight) / 2;

    canvas.save();
    canvas.translate(0, offsetY);
    canvas.scale(scale);
    game.draw(canvas, const Size(_logicalWidth, _logicalHeight));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DinoGamePainter oldDelegate) => true;
}
