# Chameleon Puzzle Game — Gameplay Recommendations for Faster Flutter + Flame Demo

## Purpose

This document captures the gameplay recommendations discussed after reviewing the current playable state of the chameleon/ladybug puzzle game.

The goal is to move the game from a slower mechanics test into a more **frenetic, fast-paced, think-quick arcade puzzle experience** where:

- The player is constantly scanning the board.
- Color mixing is used often.
- Chain reactions happen more frequently.
- FX and counters make every clear feel satisfying.
- Full columns create pressure instead of simply blocking the player.
- The game keeps its simple control scheme: movement, swallow, and spit.

This document is intended as reference material for Flutter + Flame implementation in Codex.

---

# 1. Current Gameplay Diagnosis

The current version already has strong visual charm and a clear core concept. The chameleon and ladybug board are working well as a theme.

However, the gameplay currently feels more like a **slow survival/puzzle test** than a fast arcade puzzle game.

Observed issues:

- Mixing colors is not used often enough.
- The board does not demand mixed colors frequently.
- There are moments where the player is moving and waiting, but not reacting quickly.
- The best cascade observed was low, around Cascade x2.
- Long stretches can happen without score movement or meaningful chain opportunities.
- Full columns currently feel like a blocked/dead action instead of a danger moment.
- The player may be thinking “Where can I spit this?” instead of “I need Purple now, where can I quickly make Red + Blue?”

The core mechanic is good, but the systems around it need to push the player toward faster decisions.

---

# 2. Design Direction

The game should move toward:

> Fast arcade puzzle.  
> 5x7 board.  
> Chameleon moves under columns.  
> Swallow to load colors.  
> Swallow twice to mix.  
> Spit from the bottom to push a column.  
> Connected groups clear.  
> Fast combo windows reward quick action.  
> Mixed colors create bigger rewards.  
> Full columns create danger, not blocked input.

The target feeling:

> “I see Purple, I need Red + Blue, go go go, spit, clear, combo, next!”

---

# 3. Keep the Core Controls Simple

## Non-negotiable Controls

Keep the core actions as:

1. Move left/right
2. Swallow
3. Spit

Do not add a third main action yet.

A third button risks making the game feel slower and more confusing, especially because color mixing is a passive result of swallowing.

---

# 4. Recommended Gesture Model

Since the game is planned for mobile, gestures are better than visible buttons.

Recommended gesture mapping:

| Gesture | Action |
|---|---|
| Swipe left | Move one column left |
| Swipe right | Move one column right |
| Swipe down | Swallow from current column |
| Swipe up | Spit into current column |
| Tap column | Optional: dash/move directly under that column |

## Strong Recommendation

Consider supporting:

```txt
Tap column = move directly under that column
Swipe down = swallow
Swipe up = spit
```

This may feel faster than repeated left/right swipes because the player can react instantly to board opportunities.

Since the board is only 5 columns wide, direct column movement can make the player feel agile and reduce wasted time.

## Keyboard Debug Controls

For desktop testing in Flutter/Flame, keep keyboard fallbacks:

| Key | Action |
|---|---|
| A / Left Arrow | Move left |
| D / Right Arrow | Move right |
| S / Down Arrow / J | Swallow |
| W / Up Arrow / K / Space | Spit |
| R | Reset |
| 1, 2, 3 | Switch test scenario |

---

# 5. Make Movement Snappier

The chameleon animation is charming, but the player should not feel slowed down by walking.

Recommendations:

- Keep walk animation, but shorten movement duration.
- Use a quick hop/dash between columns.
- Allow movement buffering if the player swipes during FX.
- Do not block player input for too long after small clears.
- Only lock input during critical cascade resolution if needed.

Suggested tuning:

```dart
const double chameleonMoveDuration = 0.12; // 120ms
const double swallowDuration = 0.16;
const double spitDuration = 0.18;
const double postClearPause = 0.20;
```

The game should feel responsive first, cute second.

---

# 6. Color Mixing Must Become a Core Demand

The current issue is not that color mixing is bad. The issue is that the board does not require it often enough.

If direct color clears are usually available, players will ignore mixing because it costs extra effort.

The game must create frequent “color requests.”

## Example Color Request

The board should frequently show:

```txt
Purple Purple _
```

The player then thinks:

```txt
I need Purple.
Purple = Red + Blue.
Find Red and Blue quickly.
```

This makes mixing the answer to the problem.

## Recommended Color Mixing Table

Base colors:

- Red
- Blue
- Yellow

Mixed colors:

- Purple
- Green
- Orange

Recipes:

| Ingredient A | Ingredient B | Result |
|---|---|---|
| Red | Blue | Purple |
| Blue | Red | Purple |
| Blue | Yellow | Green |
| Yellow | Blue | Green |
| Red | Yellow | Orange |
| Yellow | Red | Orange |
| Red | Red | Red |
| Blue | Blue | Blue |
| Yellow | Yellow | Yellow |

Rules:

- The chameleon can hold one active mouth color.
- If mouth is empty, swallowing stores that color.
- If holding a base color, swallowing a second base color mixes.
- If holding a mixed color, the player must spit before swallowing again.
- Mixed colors can exist on the board and be cleared.
- Mixed colors should not be used as ingredients for another mix in the MVP.

---

# 7. Mixed Colors Should Be More Valuable

If mixed colors behave exactly like base colors, mixing feels like extra work.

Mixed-color clears should be stronger, more valuable, or more useful.

## Recommended MVP Rule

```txt
Base-color clear = normal clear.
Mixed-color clear = higher score + bigger FX + combo timer bonus.
```

Example scoring:

| Clear Type | Points |
|---|---:|
| Base color bug cleared | 30 points |
| Mixed color bug cleared | 50 points |
| Cascade multiplier | +25% per cascade step |
| Combo multiplier | +10% per combo level |

## Better Gameplay Bonus

Mixed-color clears should extend the combo timer.

Example:

```txt
Mixed-color clear = +0.75s to active combo timer
```

This makes mixing directly support the frenetic gameplay loop.

---

# 8. Matching Rule

Use connected group matching, not column-only matching.

A match happens when:

```txt
3 or more same-color ladybugs are connected orthogonally.
```

Orthogonal means:

- Up
- Down
- Left
- Right

Diagonal does not count.

## Why This Matters

Column-only matches feel more like sorting.

Connected groups allow:

- Cross-column clears
- Wider chain reactions
- More board scanning
- More surprising cascades
- Better FX moments

This is important for the “chain here and there” feeling.

---

# 9. Chain Reaction / Cascade Logic

After every successful spit:

1. Find all connected same-color groups of 3+.
2. Clear all matching groups.
3. Trigger pop/splash FX.
4. Apply gravity column by column.
5. Increment cascade count.
6. Check for new matches.
7. Repeat until no more matches exist.
8. Resume player control.

## Important

Cascades should be automatic.

The player should not act during the core cascade resolution, but the delay should be short enough that the game still feels fast.

Recommended timings:

```dart
const double matchHighlightDuration = 0.12;
const double popFxDuration = 0.22;
const double gravityFallDuration = 0.18;
const double cascadeStepDelay = 0.08;
```

---

# 10. Add Player-Driven Combo Windows

Automatic cascades are not enough by themselves.

To make the game feel more frenetic, add a short combo timer after every clear.

## Rule

After any successful clear:

```txt
Start a 2.0 second combo window.
```

If the player creates another clear before the timer expires:

```txt
Combo x2
Combo x3
Combo x4
```

If the timer expires:

```txt
Combo resets.
```

This creates urgency even when the board does not auto-cascade.

## Difference Between Cascade and Combo

| System | Meaning |
|---|---|
| Cascade | Automatic chain reaction caused by gravity after one spit |
| Combo | Player creates another clear quickly within a time window |

Both can exist together.

Example:

```txt
Player spits Purple.
Cascade x2 happens automatically.
Combo timer starts.
Player quickly mixes Green and clears before timer expires.
Combo x2.
```

## Recommended Combo Timer Values

```dart
const double comboWindowBaseSeconds = 2.0;
const double comboWindowMixedClearBonus = 0.75;
const double comboWindowCascadeBonus = 0.35;
const int maxDisplayedCombo = 99;
```

---

# 11. Objectives Should Reward the Unique Mechanic

If the objective is only “score as much as possible,” players may ignore mixing.

Use objectives that reward the core mechanic.

Recommended objectives:

- Get Combo x5 before time runs out.
- Clear 12 mixed-color ladybugs.
- Trigger 3 cascades.
- Score 1500 with at least 5 mixed-color clears.
- Survive 90 seconds while keeping the board under the danger line.
- Clear 10 Purple ladybugs.
- Create 3 mixed-color clears in one round.
- Trigger Cascade x3 using a mixed-color spit.

## Recommended Next Demo Objective

For the next gameplay test:

```txt
Score 1500 in 90 seconds.
Bonus objective: Clear 10 mixed-color bugs.
Bonus objective: Reach Combo x5.
```

This keeps the round understandable while pushing the desired behavior.

---

# 12. Refill System Should Create Pressure and Opportunities

Never-ending ladybugs can work, but they should not be purely random.

The refill system should:

1. Keep pressure on the player.
2. Prevent the board from becoming too empty.
3. Create near-match opportunities.
4. Encourage mixing.

## Recommended Refill Behavior

```txt
Every 4–5 seconds, add bugs to 1–2 columns.
After every clear, add 1 new bug to a random column after a short delay.
After Combo x3+, add a small refill burst.
```

## Smart Refill Bias

The refill generator should occasionally create near-matches.

Examples:

```txt
Purple Purple _
Green _ Green
Orange Orange _
```

This encourages the player to mix and complete the opportunity.

## Avoid Full Chaos

Do not let refill be fully random at all times. If the board becomes unreadable, the player stops planning and only reacts randomly.

Use semi-smart refill logic.

---

# 13. Full Columns Should Create Danger, Not Block the Player

The current hard rule:

```txt
Column full = cannot spit
```

is safe for a puzzle demo, but bad for fast arcade pacing.

A blocked spit is a dead action. Dead actions kill momentum.

## Recommended Rule: Overload

When a column is full and the player spits into it:

```txt
The spit still works.
The new bug enters from the bottom.
The whole column pushes upward.
The top bug gets pushed out as overflow.
Overflow increases danger by 1.
```

This keeps the game moving.

The player is not punished with “nothing happened.” Instead:

```txt
Action happened.
Board changed.
Danger increased.
Keep moving.
```

## Overflow Rule

If column is not full:

```txt
Spit inserts held bug at the bottom and pushes column upward normally.
```

If column is full:

```txt
Spit inserts held bug at the bottom.
Top bug is pushed out.
Danger meter +1.
Player keeps control.
If danger reaches max, round ends.
```

Recommended starting values:

```dart
const int maxDanger = 5;
const int dangerOnOverflow = 1;
const double overflowWarningDuration = 0.5;
```

## Why This Is Better

Full columns become dangerous, not forbidden.

Sometimes the player may intentionally overload a column to:

- Save a combo
- Push bugs into alignment
- Trigger a match
- Set up a cascade
- Accept risk for a bigger clear

This is more interesting than blocking the move.

---

# 14. Visual States for Full Columns

The player needs to know when a column is risky.

Use three visual states.

## 1. Almost Full

When a column has 6 of 7 bugs:

Visuals:

- Top cell lightly pulses yellow/orange.
- Subtle warning glow.
- Optional small “!” badge.

Status text:

```txt
Almost full!
```

## 2. Full

When a column has 7 of 7 bugs:

Visuals:

- Column border glows red/orange.
- Top vine cap shakes slightly.
- Small “FULL” icon or exclamation badge above the column.
- Held spit target indicator changes to danger color.

Status text:

```txt
Full column — spitting will overload!
```

## 3. Overloaded

When the player spits into a full column:

Visuals:

- Column shakes.
- Top bug pops upward.
- Danger burst FX.
- Danger meter increases.
- Brief red flash near top of board.

Status text:

```txt
Overflow! Danger +1
```

---

# 15. UI/HUD Recommendations

The HUD should reinforce speed, combos, and color decisions.

Show:

- Score
- Timer
- Current mouth color
- Current recipe state
- Combo counter
- Cascade counter
- Danger meter
- Objective progress

## Important HUD Elements

### Mouth Color Display

Show the current held color clearly.

Examples:

```txt
Holding: Red
Holding: Red + Blue = Purple
Holding: Purple
```

### Recipe Hint

When holding a base color, show possible mixes:

```txt
Red + Blue = Purple
Red + Yellow = Orange
```

Keep it small and readable.

### Combo Counter

Large temporary text near the board:

```txt
COMBO x4
```

### Cascade Counter

Large temporary text during automatic chain reactions:

```txt
CASCADE x2
```

### Danger Meter

Could be represented as leaves, bug icons, hearts, or warning pips.

Example:

```txt
Danger: ● ● ○ ○ ○
```

---

# 16. Board Readability Recommendations

The art is charming and detailed, but fast gameplay needs quick readability.

Add subtle gameplay highlights:

## When Holding a Color

If holding Purple:

- Pulse pairs/groups of Purple that need one more bug.
- Highlight valid target columns.
- Show a small glow in the cell where the spit will enter.

## When a Mixed Color Is Needed

If the board has two Purple bugs near each other:

- Lightly pulse them.
- Optional tiny recipe icon above them: Red + Blue.

## Do Not Overdo Hints

Hints should be subtle. The game should still feel skill-based.

Use them to teach the player where to look during fast gameplay.

---

# 17. FX Recommendations for Flutter + Flame

FX are important because chain reactions and mixing should feel delightful.

## Required FX for Next Demo

Implement these minimum FX:

1. Pop FX when bugs clear.
2. Color splash FX for mixed-color clears.
3. Combo text burst.
4. Cascade text burst.
5. Column shake on overflow.
6. Board/camera shake on big cascade.
7. Danger pulse when overflow happens.
8. Chameleon flash/change color on mix.

## Existing FX Assets

If available from the asset pack, use:

```txt
fx_pop.png
fx_sparkle.png
fx_color_splash_red.png
fx_color_splash_blue.png
fx_color_splash_yellow.png
fx_combo_burst.png
```

If some color splash assets are missing, tint a generic splash sprite in Flame.

---

# 18. Flame Implementation Notes for FX

Create a centralized FX manager instead of scattering FX logic across components.

Recommended class:

```dart
class FxManager {
  void spawnPop(Vector2 position, LadybugColor color) {}
  void spawnColorSplash(Vector2 position, LadybugColor color) {}
  void spawnComboText(int combo, Vector2 position) {}
  void spawnCascadeText(int cascade, Vector2 position) {}
  void shakeColumn(int columnIndex) {}
  void shakeCamera({double intensity = 4, double duration = 0.12}) {}
  void spawnOverflowBurst(int columnIndex) {}
}
```

## Pop FX

Use `SpriteAnimationComponent` or a short scaling/fading component.

Behavior:

```txt
Spawn at cleared bug position.
Scale from 0.8 to 1.2.
Fade out quickly.
Remove component.
```

## Combo Text

Use `TextComponent` with simple movement/fade.

Behavior:

```txt
Spawn near top/middle of board.
Text: COMBO x3
Scale up quickly.
Float upward.
Fade out.
```

## Cascade Text

Use a similar text burst:

```txt
CASCADE x2
CASCADE x3
```

Cascade text should appear during automatic chain resolution.

## Camera Shake

Use Flame camera effects or manually apply a tiny offset.

Only use shake for:

- Cascade x2+
- Mixed-color clear
- Overflow
- Big clears

Avoid shaking on every tiny clear or it will become noisy.

---

# 19. Suggested Flame Components

Recommended component structure:

```txt
ChameleonGame
  BoardComponent
    CellComponent
    LadybugComponent
  ChameleonComponent
  HudOverlay / Flutter Overlay
  FxLayerComponent
  InputController
  ComboManager
  CascadeResolver
  ObjectiveManager
  RefillManager
  DangerManager
```

## Board State

Keep logic separate from visuals.

Recommended files:

```txt
lib/game/models/ladybug_color.dart
lib/game/models/board_state.dart
lib/game/models/chameleon_state.dart
lib/game/systems/color_mixer.dart
lib/game/systems/match_finder.dart
lib/game/systems/cascade_resolver.dart
lib/game/systems/combo_manager.dart
lib/game/systems/refill_manager.dart
lib/game/systems/danger_manager.dart
lib/game/components/board_component.dart
lib/game/components/ladybug_component.dart
lib/game/components/chameleon_component.dart
lib/game/components/fx_manager.dart
lib/game/chameleon_puzzle_game.dart
```

---

# 20. Combo Manager Spec

Create a dedicated combo manager.

Responsibilities:

- Track current combo count.
- Track active combo timer.
- Reset combo when timer expires.
- Increase combo when player creates a clear during active window.
- Extend timer for mixed-color clears or cascades.
- Notify HUD and FX manager.

Suggested fields:

```dart
class ComboManager {
  int combo = 0;
  double remainingWindow = 0;
  bool get isActive => remainingWindow > 0;

  void onClear({
    required bool wasPlayerDriven,
    required bool includedMixedColor,
    required int cascadeCount,
  }) {}

  void update(double dt) {}
  void reset() {}
}
```

Suggested behavior:

```txt
First clear starts Combo x1.
Next player-driven clear within 2 seconds becomes Combo x2.
Mixed color clear adds timer bonus.
Cascade can add small timer bonus but should not inflate combo too much by itself.
```

---

# 21. Cascade Counter Spec

Create a cascade resolver that returns detailed results.

Example result:

```dart
class CascadeResult {
  final int cascadeCount;
  final int bugsCleared;
  final int mixedBugsCleared;
  final bool includedMixedColor;
  final List<ClearStep> steps;
}
```

Each clear step should include:

```dart
class ClearStep {
  final int stepIndex;
  final List<GridPosition> clearedPositions;
  final Set<LadybugColor> colorsCleared;
}
```

This makes it easier to spawn FX per step and update counters.

---

# 22. Danger Manager Spec

Create a manager for overflow pressure.

Responsibilities:

- Track current danger.
- Apply danger when a column overflows.
- Trigger game over if max danger is reached.
- Notify HUD.
- Notify FX manager.

Suggested fields:

```dart
class DangerManager {
  int danger = 0;
  final int maxDanger = 5;

  bool get isGameOver => danger >= maxDanger;

  void addOverflow() {
    danger += 1;
  }

  void reduceDanger(int amount) {
    danger = max(0, danger - amount);
  }

  void reset() {
    danger = 0;
  }
}
```

Optional later:

- Reduce danger when player creates a Cascade x3+.
- Reduce danger when clearing a full column.
- Add danger over time in harder modes.

---

# 23. Refill Manager Spec

The refill manager should not be purely random.

Responsibilities:

- Add bugs over time.
- Add bugs after clears if needed.
- Create near-match opportunities.
- Avoid creating impossible/unreadable boards.
- Increase pressure over time.

Suggested fields:

```dart
class RefillManager {
  double refillTimer = 0;
  double refillInterval = 4.5;

  void update(double dt) {}
  void refillBoard(BoardState board) {}
  void createNearMatchOpportunity(BoardState board) {}
}
```

## Refill Difficulty Ramp

Over time:

```txt
0–30 sec: refill every 5.0s
30–60 sec: refill every 4.0s
60+ sec: refill every 3.25s
```

Start gentle, then ramp.

---

# 24. Spit / Overflow Logic Spec

Recommended spit behavior:

```dart
SpitResult spitIntoColumn(int columnIndex, LadybugColor color) {
  if (!board.isColumnFull(columnIndex)) {
    board.insertAtBottomAndPushUp(columnIndex, color);
    return SpitResult.normal;
  }

  final overflowBug = board.getTopBug(columnIndex);
  board.insertAtBottomPushUpAndOverflowTop(columnIndex, color);

  dangerManager.addOverflow();
  fxManager.spawnOverflowBurst(columnIndex);
  fxManager.shakeColumn(columnIndex);

  return SpitResult.overflow(overflowBug);
}
```

Important:

- A full column should not block the spit in arcade mode.
- The chameleon mouth should clear after a successful overflow spit.
- Overflow should count as a completed action.
- Overflow should trigger danger feedback.

---

# 25. Recommended Next Prototype Changes

Do not change everything at once if it becomes risky.

Recommended implementation order:

## Phase 1 — Faster Feel

- Make movement snappier.
- Add gesture controls.
- Add combo timer.
- Add combo UI text.
- Add cascade UI text.

## Phase 2 — Make Mixing Matter

- Add mixed-color objectives.
- Add mixed-color scoring bonus.
- Add mixed-color combo timer extension.
- Add board highlights for valid mixed-color opportunities.

## Phase 3 — Better Pressure

- Replace “column full block” with overflow.
- Add danger meter.
- Add visual full-column states.
- Add overflow FX.

## Phase 4 — Smarter Board

- Add semi-smart refill.
- Create near-match opportunities.
- Add difficulty ramp over time.

## Phase 5 — Juice / FX

- Add pop FX.
- Add splash FX.
- Add combo burst.
- Add camera shake.
- Add chameleon reaction animations.
- Add screen pulse for big cascades.

---

# 26. Recommended Test Scenario

For the next demo, create one scenario specifically designed to test the desired gameplay.

## Scenario: Frenzy Mix Test

Board:

- 5 columns x 7 rows.
- Timer: 90 seconds.
- Goal: Score 1500.
- Bonus goal: Clear 10 mixed-color bugs.
- Bonus goal: Reach Combo x5.
- Danger max: 5.
- Refill every 4.5 seconds.
- Smart refill occasionally creates mixed-color near-matches.

Rules:

- Swipe/tap controls.
- Swallow base colors.
- Mix colors.
- Spit from bottom.
- Connected groups clear.
- Combo timer starts after clears.
- Full columns overload instead of blocking.
- Mixed-color clears give higher score and extend combo timer.

Expected outcome:

The player should quickly scan for near-matches, mix colors often, and try to maintain combo chains.

---

# 27. Codex Implementation Prompt Add-On

Use this prompt section when asking Codex to update the Flutter + Flame demo.

```md
Update the current Flutter + Flame chameleon puzzle demo to make gameplay faster and more arcade-like.

Do not redesign the art style. Do not add monetization, accounts, level maps, or production polish.

Focus only on gameplay feel, combo systems, overflow pressure, and FX feedback.

Implement the following:

1. Make chameleon movement faster and more responsive.
2. Add gesture controls:
   - Swipe left/right to move.
   - Swipe down to swallow.
   - Swipe up to spit.
   - Optional: tap a column to dash directly under it.
3. Add player-driven combo timer:
   - Any clear starts a 2-second combo window.
   - Another clear during that window increases Combo x.
   - Mixed-color clears extend the combo timer.
4. Keep cascade logic:
   - After spit, resolve automatic chain reactions.
   - Show CASCADE x2, x3, etc.
5. Add mixed-color rewards:
   - Mixed-color clears score more.
   - Mixed-color clears trigger bigger FX.
   - Mixed-color clears extend combo time.
6. Replace the “column full blocks spit” rule:
   - Full columns now allow spitting.
   - Spitting into a full column pushes the top bug out.
   - Overflow increases a danger meter.
   - When danger reaches max, end the round.
7. Add visual states for columns:
   - 6/7 bugs = almost full warning pulse.
   - 7/7 bugs = full warning glow/badge.
   - Overflow = column shake + burst FX + danger increase.
8. Add FX:
   - Pop FX for clears.
   - Color splash FX for mixed-color clears.
   - Combo text burst.
   - Cascade text burst.
   - Camera/board shake for Cascade x2+ and overflow.
9. Add HUD elements:
   - Score
   - Timer
   - Held/mouth color
   - Combo counter
   - Cascade counter
   - Danger meter
   - Mixed-color clear progress
10. Add a new test scenario:
   - 90 second timer.
   - Goal: score 1500.
   - Bonus: clear 10 mixed-color bugs.
   - Bonus: reach Combo x5.
   - Refill every 4.5 seconds.
   - Smart refill occasionally creates mixed-color near-match opportunities.

Keep logic separated into systems/managers where possible:
- ComboManager
- CascadeResolver
- RefillManager
- DangerManager
- FxManager
- ColorMixer
- MatchFinder

After implementation, provide:
1. Files changed.
2. How to test gestures.
3. How combo/cascade differs.
4. How overflow works.
5. Any tuning constants that should be adjusted after playtesting.
```

---

# 28. Final Design Summary

The strongest direction is:

```txt
No swap.
No third action yet.
Move fast.
Swallow colors.
Mix colors.
Spit from bottom.
Push columns.
Clear connected groups.
Reward mixed colors.
Use combo timer for urgency.
Use cascades for delight.
Use overflow for pressure.
Use FX and counters to make every chain feel juicy.
```

This should move the game closer to the desired feeling:

> Fast, readable, reactive, colorful, and satisfying.
