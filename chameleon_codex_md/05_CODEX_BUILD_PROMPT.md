# Codex Build Prompt — Current Chameleon Prototype

Use this prompt for future work on the current Flutter + Flame prototype.

Before changing code, read:

1. `00_CURRENT_PROJECT_STATE.md`
2. root `README.md`
3. `test/mechanics_test.dart`

The older numbered docs are historical and may describe removed mechanics.

## Current Goal

Continue iterating on a portrait mobile arcade puzzle prototype where the player controls a chameleon below a 6x8 ladybug board.

Preserve the current gameplay unless the user explicitly asks to change it.

## Current Requirements

- Flutter + Flame game.
- 6 columns x 8 rows.
- Board asset: `board_6x8_empty.png`.
- Background asset: `backgrpund_jungle_controls.png`.
- Button controls: left, swallow, spit, right.
- Keyboard debug controls remain.
- Five active bug colors: red, blue, yellow, orange, purple.
- No color mixing.
- No green gameplay pieces.
- Same-color double swallow creates a glowing held bug.
- Glowing bug detonates only when connected orthogonally to at least one same-color piece.
- Detonation clears the full connected same-color group.
- 2x2 same-color normal blocks promote into BIG bugs.
- BIG bugs are linked 2x2 pieces, cannot be swallowed, and clear with stronger FX/points.
- Pressure waves insert synchronized full rows from the top.
- Timers, scoring, danger, levels, chain bonuses, and FX remain active.

## Implementation Guidance

- Keep rule changes covered in `test/mechanics_test.dart`.
- Do not reintroduce gesture controls unless the user asks for a new control experiment.
- Do not reintroduce color mixing unless the user explicitly changes the design.
- Do not add independent per-column top refills; they can split BIG bugs.
- If board alignment changes, tune `lib/game/board_layout.dart`.
- If HUD/controls change, tune `lib/main.dart`.
- If BIG bugs behave incorrectly, inspect `BoardState.clearCells` and `MatchSystem`.

## Verification

Run:

```sh
flutter analyze
flutter test
```

For visual changes, launch the simulator and take a screenshot.

For release to Josue's iPhone:

```sh
flutter build ios --release
xcrun devicectl device install app --device 00008140-00096D9A3684801C build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device 00008140-00096D9A3684801C com.example.chameleonPuzzleDemo
```
