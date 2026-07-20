# Team-Color Palette-Swap Shader — Design (SPI-1436)

**Issue:** [SPI-1436](https://linear.app/spiral-house/issue/SPI-1436) · Parent: SPI-1433 · 3 pts
**Status:** Approved 2026-07-20
**Refs:** `docs/ART_PIPELINE.md` §4.4, §6, §9; PRD §2.5, §2.7

## Purpose

Team color is mandatory for rendering two opposing players (PRD §2.5/§2.7). Today
team color is a whole-sprite `modulate` tint applied in `scripts/systems/map_loader.gd`
(`TEAM_TINTS`), explicitly marked as a stopgap for this issue. This story replaces that
stopgap with a Godot 4 palette-swap shader that recolors only a sprite's designated
**team-color region** at runtime, so one sprite renders in any player's color via a shader
parameter instead of duplicated art (`ART_PIPELINE.md` §6).

This is a prototype pulled forward from the art-polish phase; it proceeds on placeholder
art. It establishes the **team-color region convention** (`ART_PIPELINE.md` §9) that final
creature art will follow.

## Scope decisions

Confirmed with the product owner:

1. **Technique: hue-key + luminance-preserving tint.** The team region is authored in one
   flat "key" hue. The shader detects that key hue in `COLOR` and replaces it with the team
   color while preserving each pixel's brightness (so the region keeps its internal shading);
   all non-key pixels pass through untouched. This is KoBeWi's COLOR-in/COLOR-out approach
   (no texture lookups) scoped to a single key region — which satisfies the "recolor targets
   only the designated key / non-team regions unaffected" criterion that a full palette swap
   would violate.
2. **Key hue = magenta** (`Color(1, 0, 1)`, hue ≈ 0.833) as the convention default —
   unlikely to collide with organic sprite colors. It is a shader uniform, so art can
   standardize on any hue later without a shader change.
3. **Wire into live units, remove `modulate`.** The shader is applied to the real
   drone/mother sprites and driven by `team_id` at spawn; the `map_loader` `modulate` stopgap
   is removed.
4. **Key the placeholder art so removal is not a regression.** A committed Godot tool script
   composites a flat key-hue "core" onto the existing drone frames. The Mother reuses
   `drone_frames.tres`, so it is keyed too. This makes live units visibly recolor via the
   shader, so removing `modulate` does not lose team distinguishability in the running game.

Out of scope (owned elsewhere): final creature art (AI pipeline, later milestones); the
minimap's friendly/enemy colors (an ownership-relative concern in `minimap.gd`, distinct
from absolute team color); per-instance-uniform optimization to avoid duplicated materials
(a `gl_compatibility` renderer concern, noted as future work).

## Architecture

```
UnitBase._ready()
  └─ _apply_team_color()
       ├─ TeamColors.color_for(team_id) ─► Color            (pure lookup, headless-testable)
       └─ ShaderMaterial{ shader = team_color.gdshader,      (one instance per unit)
                          team_color = <that Color> }  ─► _sprite.material

team_color.gdshader  (canvas_item): keyed pixels ─► team_color × luminance; others pass through
```

`team_id` is set before `add_child` in both spawn paths (`map_loader.populate`,
`MotherUnit.spawn_unit`), so `_ready()` reads a valid `team_id` — no post-spawn refresh hook
is needed.

## Component 1 — `team_color.gdshader` (recolor layer)

`assets/shaders/team_color.gdshader`, `shader_type canvas_item`.

**Uniforms**

| Uniform | Type | Default | Meaning |
|---------|------|---------|---------|
| `team_color` | `vec4` (`source_color`) | `vec4(1.0)` (white) | The player's color; white = no-op |
| `key_hue` | `float` (hint_range 0,1) | `0.8333` | Hue of the team region (magenta) |
| `hue_tolerance` | `float` (hint_range 0,0.5) | `0.06` | Half-width of the matched hue band |
| `min_saturation` | `float` (hint_range 0,1) | `0.25` | Below this, a pixel is too gray to key |

**Fragment logic**

1. Read `COLOR` (the sprite pixel).
2. Convert `COLOR.rgb` → HSV.
3. Compute a keyed weight: `1.0` when the hue is within `hue_tolerance` of `key_hue` **and**
   saturation ≥ `min_saturation`, ramped to `0.0` at the band edge via `smoothstep` (soft,
   anti-aliased edges). Hue distance is computed on the circular hue axis (wrap-aware).
4. Recolored pixel = `team_color.rgb * hsv.value` (preserves the region's internal shading:
   darker key pixels → darker team color).
5. `COLOR.rgb = mix(COLOR.rgb, recolored, weight)`; `COLOR.a` unchanged.

Include `rgb2hsv`/`hsv2rgb` helper functions (or a value-only extraction) in the shader.
`team_color = white` leaves keyed pixels ≈ their own luminance in white — effectively neutral
— so an unset team is visually inert.

**Licensing note (AC):** the shader is an original implementation of the same technique
described by KoBeWi's Godot Palette Swap Shader (COLOR-in/COLOR-out, no texture lookups). No
KoBeWi source is copied, so no third-party license attaches; the file is MIT under the repo.
This is recorded in a header comment in the `.gdshader`.

## Component 2 — `TeamColors` (color source of truth)

`class_name TeamColors extends RefCounted` in `scripts/systems/team_colors.gd`. Pure data —
no scene tree — so fully headless-testable.

**API & constants**

```gdscript
const KEY_HUE: float = 0.8333  # magenta; matches the shader default
const NEUTRAL: Color = Color.WHITE
const TEAM_COLORS: Dictionary = {
    1: Color(0.30, 0.85, 0.35),  # team 1 — green
    2: Color(0.90, 0.30, 0.30),  # team 2 — red
}

static func color_for(team_id: int) -> Color  # returns TEAM_COLORS[team_id] or NEUTRAL
```

Team 1/2 colors carry the same intent as today's `TEAM_TINTS` (green / red), now expressed as
full team colors rather than a whitewash multiplier.

## Component 3 — `UnitBase` integration

`scripts/units/unit_base.gd`:

- Add `_apply_team_color()` and call it from `_ready()` (after `add_to_group`, alongside the
  other setup calls). It builds a fresh `ShaderMaterial` per unit (own instance, so two units
  never share a `team_color` param), sets `shader` to the preloaded team-color shader, sets
  the `team_color` shader parameter to `TeamColors.color_for(team_id)`, and assigns it to
  `_sprite.material`:

```gdscript
const TeamColorShader := preload("res://assets/shaders/team_color.gdshader")

func _apply_team_color() -> void:
    var mat := ShaderMaterial.new()
    mat.shader = TeamColorShader
    mat.set_shader_parameter("team_color", TeamColors.color_for(team_id))
    _sprite.material = mat
```

MotherUnit inherits this unchanged (it calls `super._ready()`), and reuses the drone
SpriteFrames, so it recolors with no Mother-specific code.

## Component 4 — Remove the `modulate` stopgap

`scripts/systems/map_loader.gd`: delete the `TEAM_TINTS` constant and the two
`_apply_team_tint(...)` calls (in the spawn-point/Mother loop and the unit loop) and the
`_apply_team_tint` method. Units self-color in `_ready()`, so the loader no longer touches
`modulate`. The comment referencing SPI-1436 goes away with the constant.

## Component 5 — Keyed placeholder art

`tools/generate_keyed_drone.gd`, a committed headless Godot script
(`godot --headless -s tools/generate_keyed_drone.gd`) that:

1. Reads each **original** drone frame (`drone_idle.png`, `drone_walk_0..3.png`) as its source.
2. Composites a flat magenta (`Color(1, 0, 1)`) key "core" — a small filled shape centered on
   the sprite body — onto each frame, over opaque body pixels only (skips transparent pixels
   so the accent stays on the creature).
3. Writes each result to a **new** `*_keyed.png` file (e.g. `drone_idle_keyed.png`) and points
   `drone_frames.tres` at the keyed files. Reading originals and writing to `_keyed` names
   keeps the generator idempotent — re-running never double-keys.

Rationale for a committed generator rather than hand-painted PNGs: it is deterministic,
re-runnable, documents exactly what the "team-color region" is on placeholder art, and keeps
the convention reproducible when frames change. Exact core size/placement is an
implementation detail verified by the in-engine screenshot (below); if a centered core lands
poorly on a frame, the script's placement constants are adjusted until the screenshot reads
correctly.

## Component 6 — Demo scene (verification)

`scenes/dev/team_color_demo.tscn` + `scripts/dev/team_color_demo.gd`: instantiates the keyed
drone sprite three times with the shader material set to team 1, team 2, and neutral colors,
laid out side by side with text labels. Running it renders the ≥2-distinct-colors proof for
the screenshot attached to the issue. This scene is dev-only and not wired into `main`.

## Data flow

`UnitBase._ready()` → `TeamColors.color_for(team_id)` (pure lookup) →
new `ShaderMaterial` on `_sprite` with `team_color` set → GPU recolors the keyed region per
frame. Spawn (`map_loader` / `MotherUnit`) sets `team_id` first, so the color is correct from
the first frame. No `modulate` involvement.

## Error / edge handling

- **Unknown / unset `team_id` (incl. 0):** `color_for` returns `NEUTRAL` (white) → keyed
  region renders at its own luminance, visually inert. No crash, no special-casing.
- **Sprite with no key-hue pixels** (e.g. final art before it adopts the convention): shader
  finds no keyed pixels → sprite renders unchanged. Safe degradation.
- **`_sprite` null:** cannot occur — `_apply_team_color` runs in `_ready`, after the
  `@onready var _sprite` is resolved, and every unit scene has an `AnimatedSprite2D`.

## Testing (TDD, red → green → refactor)

Shaders cannot be pixel-tested reliably under `--headless` (dummy renderer), so tests cover
the **wiring and mapping**; the shader itself is validated by the in-engine screenshot.

**`tests/unit/test_team_colors.gd`** (pure/headless):

1. `color_for(1)` and `color_for(2)` return distinct, non-white colors.
2. `color_for(0)` and `color_for(99)` (unknown) return `TeamColors.NEUTRAL`.
3. `KEY_HUE` equals the documented magenta hue (guards shader/const drift).

**`tests/unit/test_unit_team_color.gd`** (instantiates a real drone via `add_child_autofree`):

1. A drone with `team_id = 1` has `_sprite.material` as a `ShaderMaterial` whose `shader` is
   the team-color shader and whose `team_color` parameter equals `TeamColors.color_for(1)`.
2. A drone with `team_id = 2` gets `TeamColors.color_for(2)` — different from team 1.
3. Two drones with different `team_id`s have **different** `ShaderMaterial` instances (mutating
   one's `team_color` param does not change the other's) — guards against shared-material
   bleed.

`_sprite`/`team_id` are accessed as they already are in existing unit tests
(`tests/unit/test_engage_unit.gd`, `test_unit_harvest.gd`).

**In-engine (manual, AC "verified in-engine"):** run `scenes/dev/team_color_demo.tscn`,
capture a screenshot showing the keyed sprite in ≥2 team colors, attach it to SPI-1436.

**Project gotchas (from memory):** new `class_name` files (`TeamColors`) need
`godot --headless --import` before other scripts/tests resolve the type; GUT silently skips a
parse-errored test file while still reporting green — after adding each test file, confirm the
Scripts/Tests counts rose (grep for the filename), don't trust the summary alone.

## File summary

| File | Change |
|------|--------|
| `assets/shaders/team_color.gdshader` | New — hue-key luminance-preserving recolor shader |
| `scripts/systems/team_colors.gd` | New — `TeamColors` team_id→Color source of truth |
| `scripts/units/unit_base.gd` | Add `_apply_team_color()`, call from `_ready()` |
| `scripts/systems/map_loader.gd` | Remove `TEAM_TINTS` + `_apply_team_tint` (modulate stopgap) |
| `tools/generate_keyed_drone.gd` | New — composites the magenta key region onto drone frames |
| `assets/sprites/units/drone_*_keyed.png` (new) + `drone_frames.tres` | Keyed placeholder frames; tres repointed |
| `scenes/dev/team_color_demo.tscn` + `scripts/dev/team_color_demo.gd` | New — verification scene |
| `tests/unit/test_team_colors.gd` | New — color-mapping tests |
| `tests/unit/test_unit_team_color.gd` | New — shader-material wiring tests |
