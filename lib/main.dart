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
    final iconColor = game.showNightMode
        ? const Color(0xFF9E9E9E)
        : const Color(0xFFBDBDBD);
    return Scaffold(
      backgroundColor: bgColor,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Stack(
          children: [
            // Game canvas
            GestureDetector(
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
            // Info button (top-left corner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: Icon(Icons.info_outline, color: iconColor, size: 20),
                tooltip: 'About & Licenses',
                onPressed: () => _showAboutDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(),
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

// ══════════════════════════════════════════════════════════════════════════
//  ABOUT / LICENSE DIALOG
// ══════════════════════════════════════════════════════════════════════════

class AboutDialog extends StatelessWidget {
  const AboutDialog({super.key});

  static const String _chromiumLicense = '''
Copyright 2015 The Chromium Authors

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
  * Neither the name of Google LLC nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.''';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.videogame_asset, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Offline Dino',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'A faithful recreation of Chrome\'s offline dinosaur game, '
                'built in Dart/Flutter.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 20),

              // Licenses section
              const Text(
                'Third-Party Licenses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Chromium T-Rex Runner Assets',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sprite sheets and sound effects are from the Chromium '
                'project, licensed under the BSD 3-Clause License.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),

              // Scrollable license text
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const SingleChildScrollView(
                    child: Text(
                      _chromiumLicense,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
