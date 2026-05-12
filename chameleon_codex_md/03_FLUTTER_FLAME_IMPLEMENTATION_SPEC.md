# Chameleon Puzzle Demo — Flutter + Flame Implementation Spec

> Historical note: read `00_CURRENT_PROJECT_STATE.md` first. This file describes the original 5x7/gesture/color-mixing implementation plan and is no longer the current source of truth.

Build a mechanics-only Flutter + Flame demo using the uploaded assets.

## Recommended Dependencies

Use Flutter with Flame.

```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.18.0
```

Use a newer Flame version if the project already has one.

## Game Layout

Target portrait mobile layout.

The uploaded background is `402 x 874`, close to a vertical mobile aspect ratio.

Use:

- Background scaled to cover screen.
- Board centered horizontally in the upper/middle area.
- Chameleon positioned below the board, aligned to the active column.
- HUD overlaid using Flutter or Flame text components.

## Board Asset

Use:

```txt
assets/images/board_5x7_empty.png
```

Actual size:

```txt
374 x 480
```

The board is a visual frame. The logical grid is 5 columns x 7 rows.

Implementation recommendation:

```dart
const int columns = 5;
const int rows = 7;
```

Create a `BoardLayout` helper that computes:

```dart
Vector2 boardPosition;
Vector2 boardSize;
double cellWidth;
double cellHeight;
Vector2 cellCenter(int col, int row);
```

Important:

- Data rows should be bottom-to-top.
- Visual rendering should convert bottom row index 0 to the lowest visual row.

Suggested mapping:

```dart
visualY = boardTop + gridTopPadding + ((rows - 1 - row) * cellHeight) + cellHeight / 2;
visualX = boardLeft + gridLeftPadding + (col * cellWidth) + cellWidth / 2;
```

Because the board image includes a decorative frame, use configurable inner padding.

Suggested starting values:

```dart
final gridInsetLeft = boardSize.x * 0.09;
final gridInsetRight = boardSize.x * 0.09;
final gridInsetTop = boardSize.y * 0.08;
final gridInsetBottom = boardSize.y * 0.08;
```

Then calculate:

```dart
cellWidth = (boardSize.x - gridInsetLeft - gridInsetRight) / columns;
cellHeight = (boardSize.y - gridInsetTop - gridInsetBottom) / rows;
```

Tune these visually once assets are in the app.

## Data Model

Use enums:

```dart
enum BugColor {
  red,
  blue,
  yellow,
  green,
  purple,
  orange,
}

enum MouthType {
  empty,
  base,
  mixed,
}
```

Recommended classes:

```dart
class BoardState {
  final List<List<BugColor>> columns;
}

class ChameleonState {
  int columnIndex;
  BugColor? heldColor;
  MouthType mouthType;
}

class LevelDefinition {
  String id;
  String name;
  List<List<BugColor>> columns;
  Objective objective;
}
```

Represent each column bottom-to-top:

```dart
[
  [BugColor.blue, BugColor.blue],
  [BugColor.red],
  [],
  [BugColor.yellow],
  [],
]
```

## Component Architecture

Suggested files:

```txt
lib/main.dart
lib/game/chameleon_puzzle_game.dart
lib/game/models/bug_color.dart
lib/game/models/board_state.dart
lib/game/models/chameleon_state.dart
lib/game/models/level_definition.dart
lib/game/models/objective.dart
lib/game/systems/color_mixing_system.dart
lib/game/systems/match_system.dart
lib/game/systems/gravity_system.dart
lib/game/systems/cascade_system.dart
lib/game/components/background_component.dart
lib/game/components/board_component.dart
lib/game/components/ladybug_component.dart
lib/game/components/chameleon_component.dart
lib/game/components/fx_component.dart
lib/game/levels/demo_levels.dart
lib/game/input/gesture_input_layer.dart
```

Keep game logic testable and separated from rendering.

## Asset Loading

Load assets during `onLoad()`.

Use a central asset registry:

```dart
class GameAssets {
  static const background = 'backgrpund_jungle.png';
  static const board = 'board_5x7_empty.png';

  static String ladybug(BugColor color) => 'ladybug_${color.name}.png';

  static String chameleonIdle(BugColor? color, int frame) {
    final folder = color?.name ?? 'neutral';
    return 'chameleon/$folder/chameleon_idle0$frame.png';
  }

  static String chameleonWalk(BugColor? color, int frame) {
    final folder = color?.name ?? 'neutral';
    return 'chameleon/$folder/chameleon_walk0$frame.png';
  }

  static String chameleonSwallow(BugColor? color, int frame) {
    final folder = color?.name ?? 'neutral';
    return 'chameleon/$folder/chameleon_swallow0$frame.png';
  }
}
```

## Chameleon Animations

Available animation sets per color:

```txt
idle: 2 frames
walk: 3 frames
swallow: 3 frames
spit: reuse swallow frames reversed
```

Behavior:

- Neutral idle when mouth empty.
- Color idle when holding a color.
- Walk animation when moving left/right.
- Swallow animation after swallow action.
- Spit animation after spit action.

For spit:

```txt
swallow03 -> swallow02 -> swallow01 -> idle
```

This is acceptable for the mechanics demo because true spit frames were not found in the ZIP.

## Gesture Controls

Use gestures as the main input.

Recommended gesture scheme:

| Gesture | Action |
|---|---|
| Swipe left | Move chameleon one column left |
| Swipe right | Move chameleon one column right |
| Tap current column / lower game area | Swallow |
| Swipe up | Spit |

Important:

- Keep actions distinct.
- Do not make tap change behavior based only on whether the mouth is full.
- Swallow and spit should feel like two different actions.

Implementation notes:

- Add a Flutter `GestureDetector` around the `GameWidget`, or implement Flame gesture callbacks.
- For mobile, prefer a full-screen gesture layer.
- Use thresholds so accidental small drags do not trigger movement/spit.

Suggested thresholds:

```dart
const double horizontalSwipeThreshold = 40;
const double verticalSwipeThreshold = 50;
```

Gesture priority:

1. If vertical swipe up exceeds threshold: spit.
2. Else if horizontal swipe exceeds threshold: move left/right.
3. Else if tap: swallow.

## Debug Keyboard Controls

Keep keyboard fallback for quick desktop testing:

| Key | Action |
|---|---|
| Left / A | Move left |
| Right / D | Move right |
| Space / J | Swallow |
| Enter / K | Spit |
| R | Reset |
| 1 / 2 / 3 | Switch level |

## Ladybug Rendering

Use the 128 x 128 ladybug images, but scale them to fit the cell.

Recommended render size:

```dart
final bugSize = min(cellWidth, cellHeight) * 0.86;
```

Anchor each ladybug to center.

When a ladybug clears:

- Spawn `fx_pop.png` at its cell.
- Remove the ladybug component after a short delay or immediately if no animation system is built yet.

## FX Usage

Basic clear:

```txt
fx_pop.png
```

Cascade/combo:

```txt
fx_combo_burst.png
```

Color-specific splash:

```txt
red -> fx_color_splash_red.png
blue -> fx_color_splash_blue.png
yellow -> fx_color_splash_yellow.png
green/purple/orange -> fx_pop.png or fx_combo_burst.png for now
```

## Match Detection

Implement connected-component search over the 5 x 7 grid.

Algorithm:

1. Convert columns bottom-to-top into grid lookup.
2. For each unvisited occupied cell, flood fill up/down/left/right for same color.
3. If group size >= 3, mark group for clearing.
4. Clear all groups at once.

Do not count diagonal connections.

## Gravity

Gravity is column-based.

Since columns are bottom-to-top arrays, gravity can be implemented by compacting each column:

```dart
column.removeWhere((cell) => cell == null);
```

If using nullable fixed-size columns, compact non-null items toward index 0.

Simplest approach:

- Store each column as a variable-length list.
- Index 0 is bottom.
- A column is full when `column.length >= rows`.

## Cascade Resolution

After a successful spit:

```dart
int cascadeCount = 0;
while (true) {
  final groups = matchSystem.findMatches(board);
  if (groups.isEmpty) break;

  cascadeCount += 1;
  clear(groups);
  applyGravity();
  await showFxAndSmallDelay();
}
```

Update:

```txt
highestCascade
ladybugsRemoved
statusText
objectiveProgress
```

## Spit Push Logic

Since columns are bottom-to-top arrays, spitting into the bottom means inserting at index 0:

```dart
if (column.length >= rows) {
  status = 'Column full!';
  return;
}
column.insert(0, heldColor);
heldColor = null;
moveCount++;
resolveCascades();
```

This pushes all existing pieces up by one row.

## Swallow Logic

Swallowing removes bottom-most piece from index 0:

```dart
if (column.isEmpty) {
  status = 'Nothing to swallow!';
  return;
}
final swallowed = column.first;
// Validate mix before removing if already holding a color.
column.removeAt(0);
```

If already holding a color, validate the color mix first. If the mix is invalid, do not remove the piece.

## Notes on Gestures

Gesture controls are a good fit for this game because they keep the interface clean and make the chameleon feel tactile.

Recommended for demo:

```txt
swipe left/right = movement
single tap = swallow
swipe up = spit
```

Potential issue:

- Tap-to-swallow may cause accidental swallows.

Possible later improvement:

- Only allow swallow taps inside the current column lane.
- Add a small swallow affordance near the chameleon.
- Use a short tongue preview/highlight before swallowing.

For now, keep it simple and test the feel.
