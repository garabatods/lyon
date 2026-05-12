# Chameleon Puzzle Demo — Mechanics Spec

> Historical note: read `00_CURRENT_PROJECT_STATE.md` first. The current game no longer uses color mixing, green gameplay pieces, gesture-first controls, or passive match-3 clears.

This is the mechanics-only version of the game. The goal is to validate whether the chameleon movement, swallowing, color mixing, spitting, matching, and cascade system feels fun.

## Non-Negotiable Controls

The player must have:

1. Movement left and right
2. One action to swallow/get a ladybug
3. One action to spit the held color
4. Color mixing using the defined table

Do not add a swap button.
Do not add a third primary action for the first demo.

## Board

Use a 5 x 7 grid.

```txt
5 columns
7 rows
```

The chameleon stands below the board and is always aligned to one column.

Columns should be represented bottom-to-top in data.

Example:

```dart
// bottom-to-top
['red', 'blue', 'yellow']
```

This means red is at the bottom, blue is above red, and yellow is above blue.

## Core Game Loop

```txt
Move left/right
Swallow bottom ladybug from current column
Move left/right
Optionally swallow a second base color to mix
Move left/right
Spit held color into current column
Resolve matches
Resolve gravity
Resolve cascades
Repeat
```

## Chameleon Mouth State

The chameleon can hold one active color.

States:

```txt
empty
holding base color
holding mixed color
```

Base colors:

```txt
red
blue
yellow
```

Mixed colors:

```txt
purple
green
orange
```

When the chameleon is empty:

- Swallowing stores the swallowed color.
- The chameleon switches to that color’s idle/walk/swallow animation set.

When the chameleon holds a base color:

- Swallowing another base color mixes the two colors.
- The chameleon switches to the mixed color animation set.

When the chameleon holds a mixed color:

- The player cannot swallow again.
- Show status: `Spit first!`

After spitting:

- The chameleon mouth becomes empty.
- The chameleon returns to neutral.

## Color Mixing Table

Implement this exact table:

```txt
red + blue = purple
blue + red = purple

blue + yellow = green
yellow + blue = green

red + yellow = orange
yellow + red = orange

red + red = red
blue + blue = blue
yellow + yellow = yellow
```

If a combination is not listed:

- Do not mix.
- Show status: `Can't mix those colors!`
- Do not remove the ladybug from the board unless the mix is valid.

Important:

- Mixed colors can be on the board.
- Mixed colors can match and clear.
- Mixed colors should not be used as ingredients for another mix in the first demo.

## Swallow Mechanic

When the player performs the swallow gesture/action:

1. Check the column where the chameleon is standing.
2. If the column is empty, show `Nothing to swallow!`.
3. If the chameleon is holding a mixed color, show `Spit first!`.
4. Validate whether the bottom ladybug can be swallowed/mixed.
5. Remove only the bottom-most ladybug from that column.
6. Apply gravity to the column.
7. Update the chameleon mouth state.
8. Play the swallow animation.

Important:

- The chameleon can only swallow the bottom-most ladybug from the current column.
- Ladybugs never skip positions.
- The column collapses downward immediately after swallowing.

## Spit Mechanic

When the player performs the spit gesture/action:

1. If the chameleon is empty, show `Nothing to spit!`.
2. Check the current column.
3. If the column is full, show `Column full!` and block the action.
4. Inject the held color into the bottom of the column.
5. Push the existing column upward by one cell.
6. Clear the chameleon mouth.
7. Increment move count.
8. Play spit animation.
9. Resolve matches and cascades.

Example, bottom-to-top:

```txt
Before:
blue
red
yellow

Spit purple.

After:
purple
blue
red
yellow
```

## Match Rule

Use cluster matching, not column-only matching.

A match happens when 3 or more same-color ladybugs are connected orthogonally.

Orthogonal means:

```txt
up
down
left
right
```

Diagonal does not count.

When a matching group is found:

- Clear all ladybugs in that group.
- Spawn pop/splash FX on each cleared cell.

Multiple matching groups can clear in the same cascade step.

## Cascade / Chain Reaction Logic

After every successful spit:

1. Find all connected same-color groups of 3 or more.
2. Clear all matching groups.
3. Apply gravity to every column.
4. Increase cascade count by 1.
5. Repeat until no more matches exist.

Display:

```txt
Cascade x1
Cascade x2
Cascade x3
```

If no match happens after a spit:

```txt
No match
```

## Metrics to Track

Track these during the demo:

```txt
move count
ladybugs removed
highest cascade achieved
current held color
current level objective
status text
```

## Win / Objective Conditions

For this first playable demo, implement these objective types:

```txt
clearColor: clear X ladybugs of a specific color
clearTotal: clear X total ladybugs
reachCascade: create a cascade of X or higher
clearAll: clear the entire board
```

The level is complete when its objective is achieved.

## What Not To Build Yet

Do not build:

```txt
random endless generation
power-ups
economy
ads
accounts
level map
shop
final onboarding
complex tutorials
```
