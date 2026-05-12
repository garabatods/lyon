# Current Project State — Read First

Last updated after the 6x8 board refactor.

This file is the handoff source of truth for future Codex chats. The original numbered docs describe the first prototype idea and are now historical in several places.

## Current Rules

- Board is 6 columns x 8 rows.
- Board asset is `assets/images/board_6x8_empty.png`.
- Active bug colors are red, blue, yellow, orange, and purple.
- Green assets may exist but green is not active gameplay.
- Color mixing has been removed.
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

Mobile gameplay uses Flutter overlay buttons, not gestures.

- Left/right buttons move the chameleon one column; holding repeats.
- Swallow/spit buttons fire once per press.
- Players can drag the lowest normal/small bug from a column and drop it onto another board column.
- Dropping a dragged normal bug onto a lowest same-color normal bug merges it into one glowing bug.
- Glowing bugs do not merge with other glowing bugs.
- Dragging into full columns follows spit overflow rules: insert at the bottom, trim from the top, and add danger.
- BIG bugs cannot be dragged.
- Non-movable occupied cells are shaded on the board layer as a drag affordance.
- Keyboard debug controls remain for desktop/simulator work.
- Old tap/swipe handlers were removed from the Flame game.

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
  - Main game loop, pressure rows, scoring, timers, FX, movement, swallow/spit.
- `lib/game/board_layout.dart`
  - 6x8 board size, board aspect ratio, and invisible grid insets.
  - If bugs look off-center, adjust grid inset ratios here.
- `lib/main.dart`
  - HUD and button controls.
  - Top HUD uses `hud_top_frame.png`, `progress_fill.png`, `star_empty.png`, and `star_filled.png`.
  - Top HUD layout is: TIME left, SCORE center, LEVEL right.
  - Top HUD progress tracks score toward the next arcade level; stars fill at 30%, 60%, and 90%.
- `lib/game/components/ladybug_component.dart`
  - Ladybugs use animated keyframes in the order 01 -> 02 -> 01 -> 03 at 0.2s per frame.
- `lib/game/components/board_cell_shade_component.dart`
  - Draws the semi-transparent shade over occupied board cells that cannot currently be dragged.
- `test/mechanics_test.dart`
  - Rule-level regression tests.

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
- `Left_btn_default.png` / `Left_btn_pressed.png`
- `Right_btn_default.png` / `Right_btn_pressed.png`
- `Swallow_btn_default.png` / `Swallow_btn_pressed.png`
- `Spit_btn_default.png` / `Spit_btn_pressed.png`
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
