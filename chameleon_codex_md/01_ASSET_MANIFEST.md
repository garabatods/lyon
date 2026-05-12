# Chameleon Puzzle Demo — Asset Manifest

> Historical note: read `00_CURRENT_PROJECT_STATE.md` first. This file was written for the original prototype and may mention assets or mechanics that are no longer active.

This document describes the actual assets found in the uploaded `Archive.zip` and how the Flutter + Flame demo should use them.

## Important Notes

- The ZIP contains macOS helper files (`__MACOSX`, `.DS_Store`). Do not commit or load those.
- The background file is spelled `backgrpund_jungle.png` in the ZIP. Use that exact filename unless you rename it in the project.
- I did **not** find files with `spit` in the filename. The ZIP includes idle, walk, and swallow frames. For the first demo, use the swallow/tongue frames reversed or reused for the spit action.
- Controls should be gesture-first, not button-first.
- Keep keyboard controls as debug fallbacks for desktop testing in Codex/Flutter.

## Recommended Asset Destination

Unzip the asset contents into:

```txt
assets/images/
```

So the project structure should look like:

```txt
assets/
  images/
    backgrpund_jungle.png
    board_5x7_empty.png
    ladybug_red.png
    ladybug_blue.png
    ladybug_yellow.png
    ladybug_green.png
    ladybug_purple.png
    ladybug_orange.png
    fx_pop.png
    fx_sparkle.png
    fx_color_splash_red.png
    fx_color_splash_blue.png
    fx_color_splash_yellow.png
    fx_combo_burst.png
    ui_panel_small.png
    ui_panel_wide.png
    chameleon/
      neutral/
      red/
      blue/
      yellow/
      green/
      purple/
      orange/
```

## Asset Inventory

### Background

| File | Size | Use |
|---|---:|---|
| `backgrpund_jungle.png` | 402 x 874 | Full-screen background. Scale to cover the device screen. |

### Board

| File | Size | Use |
|---|---:|---|
| `board_5x7_empty.png` | 374 x 480 | Empty board frame with 5 columns and 7 rows. Place ladybug sprites over this. |

### Ladybugs

All ladybugs are `128 x 128` transparent PNGs.

| File | Use |
|---|---|
| `ladybug_red.png` | Red ladybug piece |
| `ladybug_blue.png` | Blue ladybug piece |
| `ladybug_yellow.png` | Yellow ladybug piece |
| `ladybug_green.png` | Green ladybug piece / mixed color |
| `ladybug_purple.png` | Purple ladybug piece / mixed color |
| `ladybug_orange.png` | Orange ladybug piece / mixed color |

### Chameleon

Each chameleon frame is `375 x 375` transparent PNG.

Available colors:

```txt
neutral
red
blue
yellow
green
purple
orange
```

Each color folder includes:

```txt
chameleon_idle01.png
chameleon_idle02.png
chameleon_walk01.png
chameleon_walk02.png
chameleon_walk03.png
chameleon_swallow01.png
chameleon_swallow02.png
chameleon_swallow03.png
```

Use animation groups:

| State | Frames |
|---|---|
| Idle | `chameleon_idle01.png`, `chameleon_idle02.png` |
| Walk | `chameleon_walk01.png`, `chameleon_walk02.png`, `chameleon_walk03.png` |
| Swallow | `chameleon_swallow01.png`, `chameleon_swallow02.png`, `chameleon_swallow03.png` |
| Spit | Reuse/reverse swallow frames for demo: `swallow03`, `swallow02`, `swallow01`, then idle |

### FX

All FX are `254 x 254` transparent PNGs.

| File | Use |
|---|---|
| `fx_pop.png` | Basic clear/pop when a ladybug disappears |
| `fx_sparkle.png` | Small delight sparkle after clears |
| `fx_color_splash_red.png` | Red clear splash |
| `fx_color_splash_blue.png` | Blue clear splash |
| `fx_color_splash_yellow.png` | Yellow clear splash |
| `fx_combo_burst.png` | Cascade/combo moment |

For green, purple, and orange clears, use `fx_pop.png` or `fx_combo_burst.png` until matching color splash assets exist.

### UI Panels

| File | Size | Use |
|---|---:|---|
| `ui_panel_small.png` | 155 x 100 | Small HUD label, move counter, held color |
| `ui_panel_wide.png` | 217 x 100 | Objective/status/cascade text |

## Pubspec Asset Declaration

Use this in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/images/backgrpund_jungle.png
    - assets/images/board_5x7_empty.png
    - assets/images/ladybug_red.png
    - assets/images/ladybug_blue.png
    - assets/images/ladybug_yellow.png
    - assets/images/ladybug_green.png
    - assets/images/ladybug_purple.png
    - assets/images/ladybug_orange.png
    - assets/images/fx_pop.png
    - assets/images/fx_sparkle.png
    - assets/images/fx_color_splash_red.png
    - assets/images/fx_color_splash_blue.png
    - assets/images/fx_color_splash_yellow.png
    - assets/images/fx_combo_burst.png
    - assets/images/ui_panel_small.png
    - assets/images/ui_panel_wide.png
    - assets/images/chameleon/neutral/
    - assets/images/chameleon/red/
    - assets/images/chameleon/blue/
    - assets/images/chameleon/yellow/
    - assets/images/chameleon/green/
    - assets/images/chameleon/purple/
    - assets/images/chameleon/orange/
```

## Flame Image Loading Paths

When using Flame’s `images.load`, load paths relative to `assets/images/`:

```dart
await images.load('backgrpund_jungle.png');
await images.load('board_5x7_empty.png');
await images.load('ladybug_red.png');
await images.load('chameleon/neutral/chameleon_idle01.png');
await images.load('fx_pop.png');
```

## Cleanup Command

After unzipping, remove macOS metadata:

```bash
find assets/images -name "__MACOSX" -type d -prune -exec rm -rf {} +
find assets/images -name ".DS_Store" -delete
find assets/images -name "._*" -delete
```
