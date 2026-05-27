# Current Project State — Read First

Last updated for the current 6x8 board build.

This file is the handoff source of truth for future Codex chats.

## Current Rules

- Board is 6 columns x 8 rows.
- Board asset is `assets/images/board_6x8_empty.png`.
- Active bug colors are red, blue, yellow, orange, and purple.
- Normal same-color groups do not clear by themselves.
- The player creates glowing bugs by swallowing the same color twice.
- A glowing bug only detonates if it is orthogonally connected to at least one same-color piece.
- Detonation clears the entire connected same-color group.
- Diagonal contact does not count.
- A 2x2 block of same-color normal bugs promotes into a BIG bug.
- BIG bugs are represented as a linked 2x2 logical piece: one anchor and three parts.
- BIG bugs cannot be swallowed.
- If a connected detonating group includes any part of a BIG bug, the whole BIG bug clears and uses stronger FX/score.
- Board removals protect BIG bugs: if a clear would shift one side of a BIG bug, the whole BIG bug is removed instead of leaving orphan parts.

## Current Controls

Mobile gameplay is drag-first.

- Players can drag a normal/small bug if it is the lowest bug in its column, or if it has at least one open in-board horizontal side at the same row.
- Dropping a dragged normal bug onto a lowest same-color normal bug merges it into one glowing bug.
- Glowing bugs do not merge with other glowing bugs.
- Dragging into full columns follows spit overflow rules: insert at the bottom, trim from the top, and add danger.
- BIG bugs cannot be dragged.
- Non-movable occupied cells are shaded on the board layer as a drag affordance.
- Keyboard debug controls remain for desktop/simulator work.

## Board And Fill

- The board uses top-hanging columns: row 0 is visually top, and the end of each column list is the lowest bug.
- Swallow removes the lowest bug from the current column.
- Spit inserts the held bug at the bottom of the current column.
- Pressure waves insert synchronized full rows from the top.
- Full-row pressure is intentional; independent per-column top inserts break BIG bugs.
- Row generation is level-tuned by `PressureRowGenerator`.
- Early pressure rows avoid immediate 2x2 BIG promotions.
- Later levels gradually allow one planned BIG setup at a time, with caps by arcade level.
- If BIG bugs already exist, pressure rows bias toward feeding normal bugs of those colors so the player can make glowing detonators.
- Tutorial or limited-board levels that should not soft-lock must set `LevelDefinition.stuckHelpEnabled`.
- Assisted stuck help triggers when there are no detonations, no available glowing-bug merge, and no usable power-up inventory, then automatically adds helper ladybugs from the bottom.
- Challenge levels should leave stuck help disabled unless the level design intentionally includes assistance.

## Important Code

- `lib/game/models/board_state.dart`
  - Owns `columnCount = 6`, `rowCount = 8`.
  - Normalizes level/test columns to 6 columns.
  - Stores and safely clears linked BIG bugs.
- `lib/game/systems/match_system.dart`
  - Finds connected same-color groups.
  - Finds glowing detonations.
  - Finds 2x2 BIG bug promotions.
- `lib/game/systems/pressure_row_generator.dart`
  - Builds level-scaled incoming rows.
  - Avoids accidental early BIG-bug lockouts.
  - Feeds normal colors that can answer existing BIG bugs.
- `lib/game/chameleon_puzzle_game.dart`
  - Main game loop, pressure rows, scoring, timers, FX, movement, and debug actions.
- `lib/game/board_layout.dart`
  - 6x8 board size, board aspect ratio, and invisible grid insets.
  - If bugs look off-center, adjust grid inset ratios here.
- `lib/main.dart`
  - HUD, power bar, pause UI, and Flutter overlays.
  - Top HUD uses `hud_top_frame.png`, `progress_fill.png`, `star_empty.png`, and `star_filled.png`.
  - Top HUD layout is: TIME left, SCORE center, LEVEL right.
  - Top HUD progress tracks score toward the next arcade level; stars fill at 30%, 60%, and 90%.
- `lib/game/components/ladybug_component.dart`
  - Ladybugs use animated keyframes in the order 01 -> 02 -> 01 -> 03 at 0.2s per frame.
- `lib/game/components/board_cell_shade_component.dart`
  - Draws the semi-transparent shade over occupied board cells that cannot currently be dragged.
- `test/mechanics_test.dart`
  - Rule-level regression tests.

## Level Design Rule

When adding or revising levels, decide explicitly whether the level can be lost. If a tutorial or limited-ladybug level should always remain recoverable, enable `stuckHelpEnabled`. If the level is a challenge built around specific conditions, move order, survival pressure, or failure/retry, leave stuck help disabled.

Levels should be mechanically valid and visually intentional. Start each non-tutorial level from a readable board pattern, not a random-looking color scatter. Use patterns such as mirror layouts, diagonal waves, color islands, rivers, bridges, nests, sprouts, or twin paths. The visual pattern should support the mechanic being taught or tested:

- `glow` levels should expose obvious same-color pair opportunities.
- `clearColor` levels should make the target color visually legible, such as a river or orchard.
- `reachCascade` levels should use bridges, layers, or staggered bands that imply chain movement.
- `clearBig` levels should show an intentional 2x2 nest and a visible same-color glow path.
- `pressure` levels should use simple repeated motifs so incoming rows add stress without making the start look random.

Avoid `surviveSeconds` as a required Map01 completion objective unless the level is intentionally about waiting under pressure. For normal map progression, pressure should be a hazard while the player completes active puzzle goals such as `makeGlow`, `clearTotal`, `clearColor`, `reachCascade`, or `clearBig`.

Every new map level should define compact `designTags`, including `pattern` plus mechanic/style tags such as `intro`, `glow`, `chain`, `big`, `pressure`, `mirror`, `diagonal`, `color-focus`, `river`, `nest`, or `twin-paths`. Future level validation should treat missing `designTags` as a design error.

Tutorial and Map01 should be designed as separate level sets:

- Tutorial has exactly 6 required levels.
- Map01 should have its own local level sequence, starting at Map01 Level 1.
- Do not describe Map01 as starting at Level 7.
- Map01 level source is `data/levels/map01.json`; run `dart run tool/generate_levels.dart` after editing it to refresh `lib/game/levels/map01_levels.g.dart`.

## Persistence And Progression Model

The app now has two separate JSON-backed `SharedPreferencesAsync` records:

- `lyon.activeGame.v1`
  - Owned by `lib/game/game_save_store.dart`.
  - Encodes `GameSave.currentVersion == 1`.
  - Stores one active run: `mode`, `levelIndex`, board columns, chameleon held state, score/level/timer/combo/danger, `powerCounts`, `ObjectiveProgress`, facing direction, and `nextBigBugId`.
  - `GameSave.columns` is the persisted board. Each saved `BoardPiece` includes `color`, `charged`, `type`, and `bigId`; `bigId` links BIG bug anchors and parts rather than representing a separate table/entity.
  - Current code uses `levelIndex` to point back to the runtime level definition list; the `LevelDefinition` and current `Objective` are not serialized.
- `lyon.playerProgress.v1`
  - Owned by `lib/game/player_progress_store.dart`.
  - Encodes `PlayerProgress.currentVersion == 1`.
  - Stores account-like progression: `hasSeenTutorialIntro`, `highestTutorialLevelCompleted`, and `unlockedModes`.
  - Tutorial completion is derived from `highestTutorialLevelCompleted >= PlayerProgress.requiredTutorialLevels`, currently 6. Completing tutorial level 6 unlocks Adventure and Time Trial.

Invalid or unknown save/progress versions decode to `null` and the corresponding store removes or resets the record. If the JSON shape changes incompatibly, bump the model version and update `test/mechanics_test.dart` / `test/player_progress_test.dart`.

## Current Assets

Required current assets include:

- `hud_top_frame.png`
- `progress_fill.png`
- `star_empty.png`
- `star_filled.png`
- `backgrpund_jungle_controls.png`
- `board_6x8_empty.png`
- `ladybug_red.png`
- `ladybug_blue.png`
- `ladybug_yellow.png`
- `ladybug_orange.png`
- `ladybug_purple.png`
- `ladybugs/<color>/ladybug_<color>_anim01.png`
- `ladybugs/<color>/ladybug_<color>_anim02.png`
- `ladybugs/<color>/ladybug_<color>_anim03.png`
- neutral plus active-color chameleon folders
- `fx_pop.png`, `fx_sparkle.png`, `fx_combo_burst.png`
- red/blue/yellow color splash FX

## Before Finishing Changes

Run:

```sh
flutter analyze
flutter test
```

For visual work, launch the iPhone simulator and take a screenshot:

```sh
flutter run -d <booted-simulator-id>
xcrun simctl io <booted-simulator-id> screenshot /tmp/chameleon_check.png
```

For Josue's iPhone release builds:

```sh
flutter build ios --release
xcrun devicectl device install app --device 00008140-00096D9A3684801C build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device 00008140-00096D9A3684801C com.example.chameleonPuzzleDemo
```
