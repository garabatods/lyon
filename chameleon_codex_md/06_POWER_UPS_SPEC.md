# Power-Ups Spec

This document captures the intended power-up design for the current LYON / Chameleon puzzle game so future Codex chats can continue from the same assumptions.

## Current Gameplay Context

- The player now moves ladybugs directly by drag.
- Bottom directional / swallow / spit buttons are legacy controls and should be replaced.
- The chameleon should remain as a cute helper / mascot, not as the main control method.
- Bottom HUD should become power-up slots.
- Early levels should start with only one usable power-up slot. The other two slots should be visible but locked, then unlock through tutorial progression.
- The top HUD progress bar should represent level progress, most likely score progress toward level completion.
- Stars should represent performance / reward tier, not separate collectibles.

## Asset Folder

Use assets from:

`assets/images/power_btns/`

Use these 180x180 assets:

- `power_btn_common.png`
- `power_btn_common_pressed.png`
- `power_btn_uncommon.png`
- `power_btn_uncommon_pressed.png`
- `power_btn_Rare.png`
- `power_btn_Rare_pressed.png`
- `power_btn_ultraRare.png`
- `power_btn_ultraRare_pressed.png`
- `power_btn_disabled.png`
- `power_btn_locked.png`
- `power_icon_berry.png`
- `power_icon_bloom.png`
- `power_icon_firefly.png`
- `power_icon_pollen.png`
- `power_icon_water.png`

Ignore:

- `power_btn.png` because it is 320x320 and not part of the consistent button set.
- `.DS_Store`

Asset strategy:

- Frames and icons are separate layers.
- All active frame/icon assets use the same 180x180 canvas.
- Draw the rarity frame first, then the icon, then optional count / lock / disabled overlay.
- Use `power_btn_locked.png` for locked slots.
- Use `power_btn_disabled.png` or dimmed icon treatment when a slot is unlocked but the player has zero uses.

## Power-Up Definitions

### Berry

- Rarity: Common
- Icon: `power_icon_berry.png`
- Frame: `power_btn_common.png`
- Pressed frame: `power_btn_common_pressed.png`
- Targeting: user can tap/select any bug anywhere on the board, not only the bottom bug.
- Effect: remove / explode the full column containing the selected bug.
- Score: no points gained.
- Purpose: survival / pressure release.
- Notes: because it gives no score, Berry should not replace the main scoring loop. It is a common tool to open space when a column becomes dangerous.

### Bloom

- Rarity: Common
- Icon: `power_icon_bloom.png`
- Frame: `power_btn_common.png`
- Pressed frame: `power_btn_common_pressed.png`
- Targeting: user can tap/select any bug anywhere on the board.
- Effect: change the full row containing the selected bug to the color of the selected bug.
- Score: no direct score unless later gameplay actions clear the changed bugs.
- Purpose: setup / combo creation.
- Notes: Bloom should create future opportunities rather than instantly solve the board.

### Pollen

- Rarity: Uncommon
- Icon: `power_icon_pollen.png`
- Frame: `power_btn_uncommon.png`
- Pressed frame: `power_btn_uncommon_pressed.png`
- Targeting: user can tap/select any board section or bug anywhere on the board.
- Effect: explode a 3x3 area centered on the selected board cell / bug.
- Score: awards points as if cleared by a regular glowing bug.
- Purpose: tactical scoring clear.
- Notes: should be useful for middle-board problems where normal bottom-only interaction would be too slow.

### Water Drop

- Rarity: Rare
- Icon: `power_icon_water.png`
- Frame: `power_btn_Rare.png`
- Pressed frame: `power_btn_Rare_pressed.png`
- Targeting: user can tap/select any bug anywhere on the board.
- Effect: remove all ladybugs of the same color as the selected bug.
- Score: awards points as if cleared by a regular glowing bug.
- Purpose: powerful color clear / scoring recovery.
- Notes: because it is board-wide and score-bearing, this should be rarer than Pollen.

### Firefly

- Rarity: Ultra Rare
- Icon: `power_icon_firefly.png`
- Frame: `power_btn_ultraRare.png`
- Pressed frame: `power_btn_ultraRare_pressed.png`
- Targeting: likely no specific target required, or tap the Firefly slot and confirm/use immediately.
- Effect: randomly remove 50% of the small ladybugs currently on the board.
- Score: awards points as if cleared by a regular glowing bug.
- Restrictions: only small ladybugs are affected. BIG ladybugs must not be removed by Firefly.
- Purpose: emergency super clear.
- Notes: this should be flashy and rare. It can save a bad board but should not remove BIG bugs.

## Bottom HUD Plan

Replace legacy controls with three power-up slots.

Recommended early layout:

- Slot 1: unlocked power-up.
- Slot 2: locked.
- Slot 3: locked.
- Chameleon remains visible as a helper / personality element.

Long-term behavior:

- Player can carry up to three active power-up types into a level.
- Locked slots should be visible to signal future progression.
- Each unlocked slot should show:
  - rarity frame
  - icon
  - count badge
  - pressed state when touched
  - disabled state when count is zero

## Tutorial / Unlock Progression

Recommended first tutorial sequence:

1. Level 1: teach dragging and same-color merge into glowing bug. No power-ups.
2. Level 2: teach top pressure and normal glowing clear scoring. Locked power-up slots may be visible.
3. Level 3: unlock first power-up slot with Berry.
4. Level 4: Berry practice. Give free Berry uses. Teach that Berry clears space but gives no points.
5. Level 5: introduce Bloom as a common reward or tutorial power. Teach row recolor as setup.
6. Level 6: introduce BIG bugs and reinforce that glowing clears are still the main scoring tool.
7. Level 7: unlock second power-up slot.
8. Level 8: introduce Pollen. Teach 3x3 scoring clear.
9. Level 10: introduce Water Drop. Teach color-wide scoring clear.
10. Later levels: unlock third power-up slot and introduce Firefly as an ultra rare reward.

This sequence can be adjusted, but the important principle is:

- Berry first because it is simple and survival-focused.
- Bloom second because it teaches setup.
- Pollen after the player understands scoring clears.
- Water Drop later because it is a strong score-bearing board-wide power.
- Firefly much later because it is a super clear.

## Reward / Rarity Direction

Suggested reward logic after completing levels:

- 1 star: mostly common choices.
- 2 stars: common plus chance of uncommon.
- 3 stars: better chance of uncommon / rare.
- Ultra rare Firefly should be special, infrequent, and possibly tied to excellent performance.

Rarity mapping:

- Common: Berry, Bloom
- Uncommon: Pollen
- Rare: Water Drop
- Ultra Rare: Firefly

## Implementation Notes

- Power-up targeting must allow selecting non-bottom bugs. This is different from normal drag/move restrictions.
- Power-ups should operate on board cells directly, not only movable bugs.
- Scoring powers should use the same score logic as glowing-bug clears where possible.
- Non-scoring powers should explicitly avoid adding score.
- BIG bug interactions must be carefully defined per power:
  - Firefly must ignore BIG bugs.
  - Berry / Pollen / Water behavior around BIG bugs should be implemented intentionally, not accidentally.
  - If uncertain, start conservatively and preserve BIG bugs unless design says otherwise.
- Add tests for each power effect before tuning visuals deeply.

