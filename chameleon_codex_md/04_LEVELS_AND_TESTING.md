# Chameleon Puzzle Demo — Levels and Testing

> Historical note: read `00_CURRENT_PROJECT_STATE.md` first. Current gameplay uses 6x8, glowing detonators, BIG bugs, and synchronized pressure rows.

Use handcrafted levels for the first demo. Do not randomize the board yet.

Board size:

```txt
5 columns x 7 rows
```

All columns are represented bottom-to-top.

## Level 1 — Basic Clear

Purpose:

- Test movement.
- Test swallowing.
- Test spitting.
- Test basic match clear.

Objective:

```txt
Clear 3 blue ladybugs.
```

Data:

```dart
LevelDefinition(
  id: 'basic_clear',
  name: 'Basic Clear',
  columns: [
    [BugColor.blue, BugColor.blue],
    [BugColor.blue],
    [BugColor.red],
    [BugColor.yellow],
    [],
  ],
  objective: Objective.clearColor(BugColor.blue, 3),
)
```

Expected test path:

```txt
Start at column 1 or move to column 2.
Swallow blue from column 2.
Move to column 1.
Spit blue into column 1.
Three connected blue ladybugs clear.
Objective completes.
```

## Level 2 — Color Mixing

Purpose:

- Test swallowing twice.
- Test color mixing.
- Test chameleon color state.
- Test clearing a mixed color.

Objective:

```txt
Clear 3 purple ladybugs.
```

Data:

```dart
LevelDefinition(
  id: 'color_mixing',
  name: 'Color Mixing',
  columns: [
    [BugColor.red],
    [BugColor.blue],
    [BugColor.purple, BugColor.purple],
    [BugColor.yellow],
    [],
  ],
  objective: Objective.clearColor(BugColor.purple, 3),
)
```

Expected test path:

```txt
Swallow red.
Swallow blue.
Chameleon holds purple.
Move to the purple column.
Spit purple.
Three purple ladybugs clear.
Objective completes.
```

## Level 3 — Cross-Column Cascade

Purpose:

- Test cluster matching across columns.
- Test cascade x2.
- Test gravity after a clear.

Objective:

```txt
Reach Cascade x2.
```

Data:

```dart
LevelDefinition(
  id: 'cross_column_cascade',
  name: 'Cross-Column Cascade',
  columns: [
    [BugColor.blue, BugColor.red],
    [BugColor.blue, BugColor.red],
    [BugColor.yellow],
    [BugColor.red, BugColor.blue],
    [BugColor.yellow, BugColor.blue],
  ],
  objective: Objective.reachCascade(2),
)
```

Implementation note:

If this level does not naturally cascade after the first implementation because of board-layout details, adjust it. The requirement is that at least one test level reliably creates a Cascade x2 or higher using cluster matching and gravity.

A good cascade level should cause:

```txt
First clear: one color group of 3+
Gravity: pieces fall downward
Second clear: a new group of 3+ forms automatically
```

## Level 4 — Spit Push Demo

Purpose:

- Test the bottom-insert / push-up spit mechanic.
- Test that spitting can realign horizontal clusters.

Objective:

```txt
Clear 6 total ladybugs.
```

Data:

```dart
LevelDefinition(
  id: 'push_setup',
  name: 'Push Setup',
  columns: [
    [BugColor.red, BugColor.blue, BugColor.yellow],
    [BugColor.yellow, BugColor.blue],
    [BugColor.red],
    [BugColor.blue, BugColor.red],
    [],
  ],
  objective: Objective.clearTotal(6),
)
```

## Testing Checklist

### Asset Loading

- Background loads.
- Board loads.
- All 6 ladybugs load.
- Chameleon neutral loads.
- Chameleon color folders load.
- FX files load.
- No `__MACOSX`, `.DS_Store`, or `._*` files are referenced.

### Movement

- Swipe left moves chameleon one column left.
- Swipe right moves chameleon one column right.
- Chameleon cannot move outside columns 0–4.
- Walk animation plays on movement.

### Swallow

- Tap triggers swallow.
- Swallow removes only the bottom-most ladybug.
- Column collapses after swallow.
- Chameleon changes to held color.
- Swallow animation plays.
- Empty column shows `Nothing to swallow!`.

### Mixing

- Red + Blue = Purple.
- Blue + Yellow = Green.
- Red + Yellow = Orange.
- Same + Same stays same.
- Mixed color cannot mix again.
- Invalid mixes do not remove the board piece.

### Spit

- Swipe up triggers spit.
- Spit injects held color at bottom of current column.
- Existing pieces shift upward.
- Full column blocks spit.
- Move counter increments only after successful spit.
- Mouth clears after successful spit.
- Spit animation uses reversed swallow frames.

### Matching

- 3+ same color connected orthogonally clears.
- Diagonal does not count.
- Matches can span multiple columns.
- Multiple groups can clear in one cascade step.

### Cascade

- After clear, gravity resolves.
- New matches clear automatically.
- Cascade count updates.
- Highest cascade updates.
- FX spawn on cleared cells.

### Objectives

- Clear color objective completes.
- Clear total objective completes.
- Reach cascade objective completes.
- Reset restarts the current level.
- Level switch loads the selected test level.
