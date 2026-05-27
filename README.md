# Chameleon Puzzle Demo

Portrait Flutter + Flame game for a chameleon/ladybug arcade puzzle.

Read `chameleon_codex_md/00_CURRENT_PROJECT_STATE.md` first before making gameplay changes. The Markdown in this repo describes the current game.

## Current Gameplay

- 6 x 8 board using `assets/images/board_6x8_empty.png`.
- Active bug colors are red, blue, yellow, orange, and purple.
- Mobile play uses direct drag controls.
- Non-movable occupied cells are shaded on the board layer to show what cannot be dragged.
- Ladybugs animate through each color's `anim01`, `anim02`, `anim01`, `anim03` frames.
- Keyboard debug controls remain.
- Swallow takes the lowest bug from the chameleon's current column.
- Same-color second swallow creates a glowing held bug.
- Dragging a lowest normal bug onto another lowest same-color bug merges it into a glowing bug.
- Spit places the held bug at the bottom of the current column.
- Normal groups do not auto-clear.
- A glowing bug detonates only when connected orthogonally to at least one same-color piece.
- Detonation clears the full connected same-color group, including chains, L-shapes, blobs, and BIG bugs.
- 2 x 2 same-color normal blocks promote into BIG bugs.
- Pressure waves insert synchronized full rows from the top so BIG bugs do not split.
- Incoming pressure rows scale by arcade level: early rows avoid accidental BIG bug floods, later rows introduce planned BIG setups, and existing BIG colors are fed back as normal bugs so the player can create detonators.
- Timer, score, level goals, danger pips, chain bonuses, and BIG/glow FX are active.
- Top HUD shows TIME, SCORE, and LEVEL using `hud_top_frame.png`.
- The progress bar tracks score progress toward the next arcade level; stars fill at 30%, 60%, and 90% of that level progress.

## Important Files

- `lib/game/models/board_state.dart` - board dimensions, piece storage, BIG bug safety.
- `lib/game/systems/match_system.dart` - connected groups, detonations, BIG promotions.
- `lib/game/systems/pressure_row_generator.dart` - level-scaled incoming row generation.
- `lib/game/chameleon_puzzle_game.dart` - main game loop, spawning, scoring, FX.
- `lib/game/board_layout.dart` - 6x8 board placement and invisible grid alignment.
- `lib/main.dart` - Flutter overlay HUD, top progress/stars, power bar, and pause UI.
- `test/mechanics_test.dart` - current rule coverage.

## Controls

| Input | Action |
| --- | --- |
| Drag movable bug | Move a lowest bug, or a bug with one open in-board horizontal side, to another column |
| Drag normal bug onto same-color lowest normal bug | Create a glowing bug |
| Left / A | Move left |
| Right / D | Move right |
| Down / S / J | Swallow |
| Up / W / Space / Enter / K | Spit |
| R | Restart current level |
| 1 / 2 / 3 / 4 | Switch debug level |

## Level Design Safety

Tutorial or limited-board levels that should not be losable through soft-locks must opt into `stuckHelpEnabled`. When an assisted level has no detonations, no available glowing-bug merge, and no usable power-up inventory, the game automatically adds helper ladybugs so the player can continue. Challenge levels should leave this disabled unless help is intentionally part of the design.

Map levels should be designed as readable board patterns, not random color scatters. Start from a visual motif such as mirror pairs, diagonal waves, color islands, rivers, bridges, nests, sprouts, or twin paths, then validate that the motif supports the objective. Each new map level should include `designTags` with `pattern` plus mechanic/style tags like `glow`, `chain`, `big`, `pressure`, `color-focus`, `mirror`, or `diagonal`.

## Verify

```sh
flutter analyze
flutter test
```

## Run

```sh
flutter pub get
flutter run
```

## Release To Josue's iPhone

Use a fresh release build; do not rely on `flutter install` because it can install stale artifacts.

```sh
flutter build ios --release
xcrun devicectl device install app --device 00008140-00096D9A3684801C build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device 00008140-00096D9A3684801C com.example.chameleonPuzzleDemo
```
