# LYON Asset Style Guide For Agents

Read this before creating, replacing, or wiring game assets. This is the current visual reference for the live Flutter/Flame build.

## Role

Use this file like a mini skill:

1. Inspect the nearby existing asset before making a new one.
2. Match the current raster style, canvas size, transparency, and naming pattern.
3. Export PNGs into the correct `assets/images/...` folder.
4. Update `pubspec.yaml` only if the asset is in a new folder.
5. Update `lib/game/assets/game_assets.dart` or the direct Flutter image path if code must load the new asset.
6. Run `flutter analyze`; run `flutter test` when code or gameplay behavior changes.

## Current Visual Direction

LYON is a bright jungle puzzle game with chunky mobile-game assets:

- Soft cartoon rendering with rounded silhouettes, big readable shapes, and playful proportions.
- Saturated candy colors on the playable objects, with warm highlights and darker edge shading.
- Forest/jungle backgrounds with deep green contrast so bugs, buttons, and HUD elements pop.
- Raster image UI, not flat vector widgets. Most visible UI surfaces are image assets.
- Crisp nearest-neighbor display in Flutter (`FilterQuality.none` appears throughout the UI), so avoid tiny antialias-dependent details.
- The feel is toy-like and tactile: buttons should look pressable, pieces should look collectible, FX should be juicy and brief.

Do not introduce a clean corporate/vector/SaaS look, thin-line icons, muted beige palettes, heavy realism, or text-heavy tutorial art.

## Reference Files To Open First

Primary current gameplay references:

- `assets/images/backgrpund_jungle_controls.png` - current gameplay background.
- `assets/images/board_6x8_empty.png` - current board frame and grid proportions.
- `assets/images/hud_top_frame.png` - current top HUD frame.
- `assets/images/ladybug_red.png` plus `assets/images/ladybugs/red/ladybug_red_anim01.png` - current piece style.
- `assets/images/chameleon/neutral/chameleon_idle01.png` - current character style.
- `assets/images/power_btns/power_btn_common.png` and `power_icon_berry.png` - power-up button/icon treatment.
- `assets/images/title_screen/title_screen_mockup2.png` - title/menu composition reference.
- `assets/images/tutorial/tutorial_modal_frame.png` - modal/tutorial frame style.

Source-art references:

- `assets/core/title_screenAll.png`
- `assets/core/gameObjets.png`
- `assets/core/gameObjets2.png`
- `assets/core/ladybugs_HD.png`
- `assets/core/fxs01.png`
- `assets/core/powers.png`

Use `assets/core` as visual source/reference only. Runtime assets should generally live under `assets/images`.

## Runtime Asset Sizes

Keep new assets on the same canvas sizes unless there is a strong implementation reason to change them.

| Asset type | Current size | Folder / examples | Notes |
|---|---:|---|---|
| Gameplay background | `402 x 874` | `assets/images/backgrpund_jungle_controls.png` | Full-screen cover art. Keep important content away from extreme edges. |
| Title background/mockup | `822 x 1786` | `assets/images/title_screen/title_background.png` | Tall mobile composition. |
| Board frame | `1191 x 1473` | `assets/images/board_6x8_empty.png` | Current live board. Match the current 6x8 sizing for new work. |
| Top HUD frame | `1191 x 280` | `assets/images/hud_top_frame.png` | Designed to align over the current 6x8 board width. |
| Progress fill | `403 x 35` | `assets/images/progress_fill.png` | Transparent PNG fill strip. |
| Ladybug pieces | `128 x 128` | `assets/images/ladybug_red.png` | Transparent square canvas. Center mass should sit comfortably inside the cell. |
| Ladybug animation frames | `128 x 128` | `assets/images/ladybugs/<color>/ladybug_<color>_anim01.png` | Three frames per active color. |
| Chameleon frames | `375 x 375` | `assets/images/chameleon/<color>/chameleon_idle01.png` | Transparent square canvas. Maintain identical registration across frames. |
| FX sprites | `254 x 254` | `assets/images/fx_pop.png` | Transparent square canvas. Keep the burst centered. |
| Pause/menu CTA buttons | `75 x 72` | `play_cta.png`, `close_cta.png` | Small icon buttons. |
| Pause button | `83 x 81` | `puase_btn.png` | Filename is misspelled in the project; preserve it unless refactoring code. |
| Pause/tutorial modal frame | `419 x 570` | `Pause_menu_modal.png`, `tutorial_modal_frame.png` | Tall centered mobile modal frame. |
| Small panel | `155 x 100` | `ui_panel_small.png` | Compact HUD panel. |
| Wide panel | `217 x 100` | `ui_panel_wide.png` | Objective/status panel. |
| Stars | `73 x 73` | `star_empty.png`, `star_filled.png` | HUD/rating star. |
| Power buttons/icons | `180 x 180` | `assets/images/power_btns/` | Button frames and icons use the same square canvas. |
| Tutorial spot art | `256 x 256` | `assets/images/tutorial/tutorial_step_drag.png` | Simple centered instructional image. |
| Lock badge | `160 x 160` | `assets/images/tutorial/tutorial_lock_badge.png` | Transparent square badge. |

## Gameplay Layout Constraints

The live board layout is controlled by `lib/game/board_layout.dart`.

- Board columns: `6`
- Board rows: `8`
- Board source size: `1191 x 1473`
- Board displayed width: `min(screenWidth * 0.94, 390)`
- Board top: `max(150, screenHeight * 0.165)`
- Grid insets as ratios of displayed board:
  - left `0.075`
  - right `0.072`
  - top `0.088`
  - bottom `0.066`
- Ladybug visual size: `min(cellWidth, cellHeight) * 0.86`
- Chameleon visual size: `cellWidth * 2.15`

When changing board art, preserve the transparent/visual grid alignment implied by these ratios or adjust `BoardLayout` in the same change.

## Color And Piece Rules

Active gameplay colors:

- red
- blue
- yellow
- orange
- purple

Green exists in the asset set but is not active gameplay right now. Do not add green mechanics unless the rules change.

Expected color treatment:

- Red: warm, saturated, readable against green jungle and dark HUD.
- Blue: bright cyan/blue, not navy.
- Yellow: golden, high contrast without washing out.
- Orange: fruit/coral orange, distinct from red.
- Purple: grape/magenta purple, distinct from blue.
- Neutral chameleon: green character base.
- Colored chameleons: same character silhouette and shading, with only the color-state treatment changing.

All piece variants must remain identifiable at small in-game size. Avoid details that only read at full PNG resolution.

## Animation Registration

Every animation frame in a set must share:

- identical canvas size,
- identical anchor/feet/body registration,
- similar silhouette footprint,
- transparent background,
- no frame-to-frame crop jumps.

Current animation sets:

- Ladybug: `ladybug_<color>_anim01.png`, `anim02`, `anim03`
- Chameleon idle: `chameleon_idle01.png`, `idle02`
- Chameleon walk: `chameleon_walk01.png`, `walk02`, `walk03`
- Chameleon swallow: `chameleon_swallow01.png`, `swallow02`, `swallow03`

For pressed/default UI assets, the pressed state should feel pushed down or lit, but the icon and hit shape must stay registered.

## Naming And Folder Patterns

Use exact lowercase active color names from `BugColor`: `red`, `blue`, `yellow`, `orange`, and `purple`.

Current patterns:

```txt
assets/images/ladybug_<color>.png
assets/images/ladybugs/<color>/ladybug_<color>_anim01.png
assets/images/ladybugs/<color>/ladybug_<color>_anim02.png
assets/images/ladybugs/<color>/ladybug_<color>_anim03.png
assets/images/chameleon/<color>/chameleon_idle01.png
assets/images/chameleon/<color>/chameleon_walk01.png
assets/images/chameleon/<color>/chameleon_swallow01.png
assets/images/fx_color_splash_<color>.png
assets/images/power_btns/power_btn_<rarity>.png
assets/images/power_btns/power_btn_<rarity>_pressed.png
assets/images/power_btns/power_icon_<name>.png
assets/images/tutorial/tutorial_step_<name>.png
```

Preserve existing typos in filenames that code already uses (`backgrpund_jungle_controls.png`, `puase_btn.png`) unless the task explicitly includes a rename/refactor.

## Creating New Asset Families

Ladybug color variant:

- Create the static piece at `128 x 128`.
- Create three animated frames at `128 x 128`.
- Match body size, shadow, highlight, and spot language to the existing ladybugs.
- Wire the color in `BugColor`, `GameAssets`, tests, and levels only if gameplay should use it.

Chameleon color/state variant:

- Create all required frames for the color folder at `375 x 375`.
- Keep the same posture and body registration as existing frames.
- Do not create a new silhouette for a color state.

FX variant:

- Use `254 x 254`.
- Center the impact point.
- Keep the burst readable in less than half a second.
- For color splashes, match the color family without obscuring the bug or board.

Power-up:

- Use a `180 x 180` icon in `assets/images/power_btns`.
- Keep the icon bold and symbolic; it must read inside an existing power button frame.
- Follow the rarity frame already specified in `06_POWER_UPS_SPEC.md`.

Tutorial art:

- Use `256 x 256` unless replacing a modal/frame.
- Make the image self-explanatory without adding text inside the PNG.
- Match the chunky, rounded game-object rendering.

Modal or HUD panel:

- Use the matching current frame size.
- Leave safe interior space for Flutter text overlays.
- Do not bake dynamic labels, scores, timers, or localized copy into the image.

## Export Requirements

- PNG, transparent background for sprites, buttons, frames, FX, icons, and panels.
- RGB/RGBA is fine, but runtime transparent assets must actually include alpha.
- Do not include macOS metadata files (`__MACOSX`, `.DS_Store`, `._*`).
- Keep source/reference art out of runtime paths unless it is intentionally loaded.
- Do not overwrite existing assets without checking every direct path reference in `lib/`.

Cleanup command after importing zipped art:

```sh
find assets/images -name "__MACOSX" -type d -prune -exec rm -rf {} +
find assets/images -name ".DS_Store" -delete
find assets/images -name "._*" -delete
```

## Quick Agent Prompt

When asking another agent or image model to create art, start with this:

```txt
Create a transparent PNG asset for LYON, a bright cartoon jungle mobile puzzle game. Match the existing chunky raster style: rounded toy-like shapes, saturated candy colors, soft highlights, darker edge shading, and crisp readability at small in-game scale. Use the exact canvas size and naming pattern from chameleon_codex_md/07_ASSET_STYLE_GUIDE.md. Do not add text to the image. Keep the subject centered and registered with the existing asset family.
```

Then add the exact asset type, canvas size, target folder, color/state, and reference files to compare against.
