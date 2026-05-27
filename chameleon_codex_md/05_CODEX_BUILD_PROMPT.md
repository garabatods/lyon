# Codex Build Prompt — Current Chameleon Game

Use this prompt for future work on the current Flutter + Flame game.

Before changing code, read:

1. `00_CURRENT_PROJECT_STATE.md`
2. root `README.md`
3. `test/mechanics_test.dart`

Use the Markdown in this repo for the current game.

## Current Goal

Continue iterating on a portrait mobile arcade puzzle game with a chameleon helper below a 6x8 ladybug board.

Preserve the current gameplay unless the user explicitly asks to change it.

## Current Requirements

- Flutter + Flame game.
- 6 columns x 8 rows.
- Board asset: `board_6x8_empty.png`.
- Background asset: `backgrpund_jungle_controls.png`.
- Mobile controls are drag-first.
- Keyboard debug controls remain.
- Active bug colors are red, blue, yellow, orange, and purple.
- Same-color double swallow creates a glowing held bug.
- Glowing bug detonates only when connected orthogonally to at least one same-color piece.
- Detonation clears the full connected same-color group.
- 2x2 same-color normal blocks promote into BIG bugs.
- BIG bugs are linked 2x2 pieces, cannot be swallowed, and clear with stronger FX/points.
- Pressure waves insert synchronized full rows from the top.
- Tutorial or limited-board levels that should not soft-lock use `stuckHelpEnabled` to add helper ladybugs automatically.
- Timers, scoring, danger, levels, chain bonuses, and FX remain active.

## Implementation Guidance

- Keep rule changes covered in `test/mechanics_test.dart`.
- Preserve the current drag/glow/BIG-bug rules unless the user explicitly changes the design.
- When creating or revising a level, ask whether it should have stuck help or whether it is allowed to be lost/retried.
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
