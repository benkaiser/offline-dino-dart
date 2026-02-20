# Offline Dino (Dart/Flutter)

A faithful recreation of Chrome's offline dinosaur game, built entirely in Dart/Flutter. Runs natively on macOS, iOS, Android, Linux, Windows, and web.

## Features

- **Authentic gameplay** — physics, speed progression, scoring, and collision detection matching the original Chromium implementation
- **Original sprite sheet** — uses the same 1233x100 sprite sheet from the Chromium source
- **Original sound effects** — jump, score achievement, and game over sounds from the Chromium source
- **Night mode** — cycling dark mode with moon phases and scrolling stars, just like the original
- **Score tracking** — current score with high score persistence, achievement flash every 100 points
- **All obstacle types** — small cacti, large cacti (single and grouped), and pterodactyls at multiple heights
- **Cross-platform input** — keyboard (Space/Up to jump, Down to duck) and touch (tap to jump, swipe down to duck)

## Controls

| Action | Keyboard | Touch |
|--------|----------|-------|
| Jump | `Space` or `Arrow Up` | Tap |
| Duck | `Arrow Down` (hold) | Swipe down (hold) |
| Start / Restart | `Space` or `Arrow Up` | Tap |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.11+)

### Run

```bash
flutter pub get
flutter run
```

To target a specific platform:

```bash
flutter run -d macos
flutter run -d chrome
flutter run -d ios
flutter run -d android
```

## Project Structure

```
lib/
  main.dart              # App entry point, widget tree, input handling
  game/
    game.dart            # Main game engine, state management, drawing
    trex.dart            # T-Rex player character (jump, duck, animate)
    horizon.dart         # Scrolling ground, clouds, night mode (moon/stars)
    obstacle.dart        # Obstacle spawning and management
    sprites.dart         # Sprite sheet definitions and drawing helpers
    sound.dart           # Sound effects playback
    constants.dart       # Game constants matching original Chromium values
assets/
    100-offline-sprite.png   # 1x sprite sheet from Chromium
    200-offline-sprite.png   # 2x sprite sheet from Chromium
    button-press.ogg         # Jump sound from Chromium
    hit.ogg                  # Game over sound from Chromium
    score-reached.ogg        # Score achievement sound from Chromium
```

## Third-Party Assets

The sprite sheets (`100-offline-sprite.png`, `200-offline-sprite.png`) and sound effects (`button-press.ogg`, `hit.ogg`, `score-reached.ogg`) are from the [Chromium project](https://chromium.googlesource.com/chromium/src/+/main/components/neterror/resources/) and are used under the BSD 3-Clause License. See [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) for full license text.

The game logic is a clean-room reimplementation in Dart/Flutter, referencing the original Chromium TypeScript/JavaScript source for accuracy.

## License

This project's Dart/Flutter code is available under the [MIT License](LICENSE).

The Chromium assets bundled in `assets/` are licensed under the BSD 3-Clause License — see [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
