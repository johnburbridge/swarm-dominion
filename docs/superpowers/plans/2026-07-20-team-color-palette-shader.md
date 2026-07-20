# Team-Color Palette-Swap Shader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the whole-sprite `modulate` team tint with a Godot 4 palette-swap shader that recolors only a sprite's designated magenta key region to the owning player's color, driven by `team_id` at runtime.

**Architecture:** A `canvas_item` hue-key shader recolors magenta pixels to `team_color` while preserving their luminance; all other pixels pass through. `UnitBase._ready()` builds a per-unit `ShaderMaterial` and sets `team_color` from `TeamColors.color_for(team_id)`. The `map_loader` `modulate` stopgap is removed, and the placeholder drone frames get a magenta key core so live units visibly recolor.

**Tech Stack:** Godot 4.7 (`gl_compatibility` renderer), GDScript, GUT 9.5.0, gdformat/gdlint.

## Global Constraints

- Godot 4.7.stable; `gl_compatibility` (OpenGL) renderer.
- Key hue = magenta `Color(1, 0, 1)`, hue ≈ `0.8333`. Shared verbatim between `TeamColors.KEY_HUE`, the shader's `key_hue` default, and the art generator's `KEY_COLOR`.
- Team colors: team 1 = `Color(0.3, 0.85, 0.35)` (green), team 2 = `Color(0.9, 0.3, 0.3)` (red); unknown/0 = `Color.WHITE` (neutral, visual no-op).
- Each unit gets its **own** `ShaderMaterial` instance (no shared `team_color` param across units).
- Shader is an original implementation (KoBeWi technique, no copied source) → MIT under this repo; record this in a header comment.
- `gdformat scripts/` and `gdlint scripts/` must be clean; regular `var` before `@onready var`; consts before vars.
- New `class_name` files (`TeamColors`) need `godot --headless --import` before other scripts/tests resolve the type.
- GUT silently skips a parse-errored test file while still reporting green — after adding each test file, confirm the Scripts/Tests counts rose (grep for the filename), don't trust the summary alone.
- Full suite runs headless: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

---

### Task 1: `TeamColors` — color source of truth

**Files:**
- Create: `scripts/systems/team_colors.gd`
- Test: `tests/unit/test_team_colors.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name TeamColors`; `const KEY_HUE: float`, `const NEUTRAL: Color`, `const TEAM_COLORS: Dictionary`; `static func color_for(team_id: int) -> Color`.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_team_colors.gd`:

```gdscript
extends GutTest
## Tests for TeamColors team_id -> Color mapping (SPI-1436).


func test_color_for_returns_distinct_team_colors() -> void:
	var c1 := TeamColors.color_for(1)
	var c2 := TeamColors.color_for(2)
	assert_ne(c1, c2, "team 1 and team 2 should map to different colors")
	assert_ne(c1, TeamColors.NEUTRAL, "team 1 color should not be the neutral fallback")
	assert_ne(c2, TeamColors.NEUTRAL, "team 2 color should not be the neutral fallback")


func test_color_for_unknown_team_returns_neutral() -> void:
	assert_eq(TeamColors.color_for(0), TeamColors.NEUTRAL, "team 0 should be neutral")
	assert_eq(TeamColors.color_for(99), TeamColors.NEUTRAL, "unknown team should be neutral")


func test_key_hue_is_magenta() -> void:
	assert_almost_eq(TeamColors.KEY_HUE, 0.8333, 0.001, "key hue should be magenta (~0.8333)")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL — parse error / "Identifier 'TeamColors' not declared" (the class does not exist yet).

- [ ] **Step 3: Write the implementation**

Create `scripts/systems/team_colors.gd`:

```gdscript
class_name TeamColors extends RefCounted
## Single source of truth mapping team_id -> the color a unit renders in via the
## team-color palette-swap shader (SPI-1436). Pure data; no scene tree.

## Hue of the team-color key region in authored sprites (magenta). Kept in sync
## with the `key_hue` default in assets/shaders/team_color.gdshader.
const KEY_HUE: float = 0.8333

## Color used when a team_id has no assigned color (unset / neutral). White is a
## visual no-op for the shader (keyed pixels render at their own luminance).
const NEUTRAL: Color = Color.WHITE

## Absolute per-team colors. Team 1 green, team 2 red — same intent as the old
## map_loader modulate stopgap, now full colors instead of a whitewash tint.
const TEAM_COLORS: Dictionary = {
	1: Color(0.3, 0.85, 0.35),
	2: Color(0.9, 0.3, 0.3),
}


## Returns the color for team_id, or NEUTRAL if the team has no assigned color.
static func color_for(team_id: int) -> Color:
	return TEAM_COLORS.get(team_id, NEUTRAL)
```

- [ ] **Step 4: Import so the new class_name resolves**

Run: `godot --headless --import`
Expected: completes without a fatal error (import warnings are fine).

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. Confirm `test_team_colors.gd` actually ran — grep the log for `test_team_colors` and that its 3 tests are counted (a skipped parse-errored file would still show green).

- [ ] **Step 6: Format, lint, commit**

```bash
gdformat scripts/systems/team_colors.gd
gdlint scripts/systems/team_colors.gd
git add scripts/systems/team_colors.gd tests/unit/test_team_colors.gd
git commit -m "feat: add TeamColors team_id->color source of truth (SPI-1436)"
```

---

### Task 2: Shader + `UnitBase` wiring + remove `modulate` stopgap

**Files:**
- Create: `assets/shaders/team_color.gdshader`
- Modify: `scripts/units/unit_base.gd` (add a const near the other consts; add a call in `_ready()`; add `_apply_team_color()`)
- Modify: `scripts/systems/map_loader.gd` (remove `TEAM_TINTS`, the two `_apply_team_tint(...)` calls, and the `_apply_team_tint` method)
- Test: `tests/unit/test_unit_team_color.gd`

**Interfaces:**
- Consumes: `TeamColors.color_for(team_id) -> Color` (Task 1).
- Produces: `const UnitBase.TEAM_COLOR_SHADER` (a `Shader`); `UnitBase._apply_team_color() -> void`; every unit's `_sprite.material` is a `ShaderMaterial` using that shader with a `team_color` param.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_unit_team_color.gd`:

```gdscript
extends GutTest
## Tests that UnitBase wires the team-color shader from team_id (SPI-1436).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	add_child_autofree(unit)
	return unit


func test_unit_sprite_uses_team_color_shader_material() -> void:
	var unit := _create_unit(1)
	var mat := unit._sprite.material as ShaderMaterial
	assert_not_null(mat, "sprite should have a ShaderMaterial")
	assert_eq(mat.shader, UnitBase.TEAM_COLOR_SHADER, "should use the team-color shader")
	assert_eq(
		mat.get_shader_parameter("team_color"),
		TeamColors.color_for(1),
		"team_color param should match team 1's color"
	)


func test_team_id_two_gets_its_color() -> void:
	var unit := _create_unit(2)
	var mat := unit._sprite.material as ShaderMaterial
	assert_eq(
		mat.get_shader_parameter("team_color"),
		TeamColors.color_for(2),
		"team_color param should match team 2's color"
	)


func test_two_units_have_independent_materials() -> void:
	var u1 := _create_unit(1)
	var u2 := _create_unit(2)
	var m1 := u1._sprite.material as ShaderMaterial
	var m2 := u2._sprite.material as ShaderMaterial
	assert_ne(m1, m2, "each unit should get its own ShaderMaterial instance")
	m1.set_shader_parameter("team_color", Color.BLACK)
	assert_eq(
		m2.get_shader_parameter("team_color"),
		TeamColors.color_for(2),
		"changing one unit's material must not change another's"
	)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL — `UnitBase.TEAM_COLOR_SHADER` not declared / `_sprite.material` is null (no shader wired yet).

- [ ] **Step 3: Create the shader**

Create `assets/shaders/team_color.gdshader`:

```glsl
// Team-color palette-swap shader (SPI-1436).
// Original implementation of the hue-key palette-swap technique described by
// KoBeWi's Godot Palette Swap Shader (reads/writes COLOR directly, no texture
// lookups). No third-party source is copied; MIT under this repo.
shader_type canvas_item;

// The player's team color. White (default) is a visual no-op.
uniform vec4 team_color : source_color = vec4(1.0);
// Hue of the team-color key region in the sprite (magenta). Matches TeamColors.KEY_HUE.
uniform float key_hue : hint_range(0.0, 1.0) = 0.8333;
// Half-width of the matched hue band.
uniform float hue_tolerance : hint_range(0.0, 0.5) = 0.06;
// Pixels less saturated than this are treated as non-team (hue is unstable there).
uniform float min_saturation : hint_range(0.0, 1.0) = 0.25;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 tex = COLOR;
	vec3 hsv = rgb_to_hsv(tex.rgb);
	// Circular hue distance to the key hue.
	float dh = abs(hsv.x - key_hue);
	dh = min(dh, 1.0 - dh);
	// Weight: 1 inside the band (and saturated enough), ramping to 0 at the edge.
	float hue_w = 1.0 - smoothstep(hue_tolerance, hue_tolerance * 2.0, dh);
	float sat_w = step(min_saturation, hsv.y);
	float w = hue_w * sat_w;
	// Recolor preserves the region's internal shading via the original value.
	vec3 recolored = team_color.rgb * hsv.z;
	COLOR.rgb = mix(tex.rgb, recolored, w);
}
```

- [ ] **Step 4: Wire the shader into `UnitBase`**

In `scripts/units/unit_base.gd`, add the shader const immediately after the existing `const ARRIVAL_THRESHOLD` line:

```gdscript
## Palette-swap shader that recolors the sprite's team-color key region (SPI-1436).
const TEAM_COLOR_SHADER := preload("res://assets/shaders/team_color.gdshader")
```

In `_ready()`, add the call after `_setup_selection_circle()`:

```gdscript
func _ready() -> void:
	add_to_group("units")
	_target_position = position
	_load_stats()
	_setup_attack_area()
	_setup_selection_circle()
	_apply_team_color()
	EventBus.unit_died.connect(_on_unit_died)
```

Add the method (place it just after `_setup_selection_circle()`'s definition):

```gdscript
## Applies the team-color palette-swap shader to this unit's sprite, tinting the
## key-hue region to this team's color (SPI-1436). Each unit gets its own
## ShaderMaterial so per-unit team_color params never bleed across units.
func _apply_team_color() -> void:
	var material := ShaderMaterial.new()
	material.shader = TEAM_COLOR_SHADER
	material.set_shader_parameter("team_color", TeamColors.color_for(team_id))
	_sprite.material = material
```

- [ ] **Step 5: Remove the `modulate` stopgap from `map_loader`**

In `scripts/systems/map_loader.gd`:

Delete the `TEAM_TINTS` const block (the `## Temporary team tint ...` comment and the dictionary):

```gdscript
## Temporary team tint — a stopgap until the SPI-1436 palette-swap shader lands.
const TEAM_TINTS: Dictionary = {
	1: Color(0.6, 1.0, 0.6),
	2: Color(1.0, 0.7, 0.7),
}
```

In the spawn-point loop, delete the `_apply_team_tint(mother, spawn["team_id"])` line so it reads:

```gdscript
	for spawn in definition.spawn_points:
		var mother := MotherScene.instantiate() as MotherUnit
		mother.team_id = spawn["team_id"]
		mother.position = spawn["position"]
		parent.add_child(mother)
		result["mothers"].append(mother)
```

In `_build_unit`, delete the `_apply_team_tint(unit, unit_def["team_id"])` line so it reads:

```gdscript
static func _build_unit(unit_def: Dictionary) -> UnitBase:
	var unit_type: String = unit_def["type"]
	if unit_type != "drone":
		push_warning("MapLoader: unknown unit type '%s', skipping" % unit_type)
		return null
	var unit := DroneScene.instantiate() as UnitBase
	unit.team_id = unit_def["team_id"]
	unit.position = unit_def["position"]
	return unit
```

Delete the now-unused method:

```gdscript
static func _apply_team_tint(node: CanvasItem, team_id: int) -> void:
	node.modulate = TEAM_TINTS.get(team_id, Color.WHITE)
```

- [ ] **Step 6: Import and run the test to verify it passes**

Run: `godot --headless --import`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. Confirm `test_unit_team_color.gd` ran (grep the log for it and its 3 tests) and that the existing `test_map_loader.gd` tests still pass (no test asserts on the removed tint, so they should be unaffected).

- [ ] **Step 7: Format, lint, commit**

```bash
gdformat scripts/units/unit_base.gd scripts/systems/map_loader.gd
gdlint scripts/units/unit_base.gd scripts/systems/map_loader.gd
git add assets/shaders/team_color.gdshader scripts/units/unit_base.gd scripts/systems/map_loader.gd tests/unit/test_unit_team_color.gd
git commit -m "feat: recolor units via team-color shader, drop modulate tint (SPI-1436)"
```

---

### Task 3: Keyed placeholder art (generator + committed keyed frames)

**Files:**
- Create: `tools/generate_keyed_drone.gd`
- Modify (regenerated bytes, same paths): `assets/sprites/units/drone_idle.png`, `drone_walk_0.png`, `drone_walk_1.png`, `drone_walk_2.png`, `drone_walk_3.png`
- Test: `tests/unit/test_keyed_frames.gd`

**Interfaces:**
- Consumes: nothing (reads/writes PNG files). Uses the same magenta as `TeamColors.KEY_HUE` / the shader `key_hue`.
- Produces: the drone frame PNGs each carry a magenta (`Color(1,0,1)`) core at their center that the team-color shader recolors. `drone_frames.tres` is unchanged (same paths + import UIDs), so the Mother (which reuses it) is keyed too.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_keyed_frames.gd`:

```gdscript
extends GutTest
## Verifies the drone placeholder frames carry the magenta team-color key core
## the shader depends on (SPI-1436). Loads the raw PNG (bypasses import format).

const FRAMES: Array[String] = [
	"res://assets/sprites/units/drone_idle.png",
	"res://assets/sprites/units/drone_walk_0.png",
	"res://assets/sprites/units/drone_walk_1.png",
	"res://assets/sprites/units/drone_walk_2.png",
	"res://assets/sprites/units/drone_walk_3.png",
]


func test_every_frame_has_a_magenta_key_core() -> void:
	for path in FRAMES:
		var image := Image.load_from_file(path)
		assert_not_null(image, "frame should load: %s" % path)
		var center := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
		assert_almost_eq(center.r, 1.0, 0.15, "%s center should be magenta (high red)" % path)
		assert_almost_eq(center.g, 0.0, 0.15, "%s center should be magenta (no green)" % path)
		assert_almost_eq(center.b, 1.0, 0.15, "%s center should be magenta (high blue)" % path)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL — the current placeholder frames have no magenta center, so the color asserts fail.

- [ ] **Step 3: Write the generator**

Create `tools/generate_keyed_drone.gd`:

```gdscript
extends SceneTree
## Headless generator: composites a flat magenta team-color key "core" onto the
## drone placeholder frames, in place (SPI-1436). Idempotent — a frame whose
## center is already the key color is skipped, so re-runs never double-key.
##
## Run: godot --headless -s tools/generate_keyed_drone.gd

const FRAMES: Array[String] = [
	"res://assets/sprites/units/drone_idle.png",
	"res://assets/sprites/units/drone_walk_0.png",
	"res://assets/sprites/units/drone_walk_1.png",
	"res://assets/sprites/units/drone_walk_2.png",
	"res://assets/sprites/units/drone_walk_3.png",
]

## Magenta key color (matches TeamColors.KEY_HUE / the shader's key_hue default).
const KEY_COLOR: Color = Color(1, 0, 1)
## Half-size of the square key core, in pixels, centered on the sprite.
const CORE_HALF: int = 4
## Minimum alpha for a pixel to count as "body" (skip transparent pixels).
const BODY_ALPHA: float = 0.5


func _init() -> void:
	for path in FRAMES:
		_key_frame(path)
	quit()


func _key_frame(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null:
		push_error("generate_keyed_drone: could not load %s" % path)
		return
	var cx := image.get_width() / 2
	var cy := image.get_height() / 2
	if image.get_pixel(cx, cy).is_equal_approx(KEY_COLOR):
		print("skip (already keyed): %s" % path)
		return
	for y in range(cy - CORE_HALF, cy + CORE_HALF):
		for x in range(cx - CORE_HALF, cx + CORE_HALF):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if image.get_pixel(x, y).a < BODY_ALPHA:
				continue
			image.set_pixel(x, y, KEY_COLOR)
	image.save_png(path)
	print("keyed: %s" % path)
```

- [ ] **Step 4: Run the generator, then re-import the changed textures**

Run: `godot --headless -s tools/generate_keyed_drone.gd`
Expected: prints `keyed: res://assets/sprites/units/drone_idle.png` (and the 4 walk frames).
Run: `godot --headless --import`
Expected: re-imports the changed PNGs (UIDs preserved).

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. Confirm `test_keyed_frames.gd` ran (grep the log for it).

If a `walk` frame's center is transparent (core landed off-body) and the test fails for that frame, widen `CORE_HALF` or nudge the center offset in the generator, re-run Steps 4–5. (The idempotency guard means re-running on already-keyed frames is a no-op; delete + `git checkout` the frame to start from the pristine source if you need to re-key from scratch.)

- [ ] **Step 6: Commit**

```bash
git add tools/generate_keyed_drone.gd assets/sprites/units/drone_idle.png assets/sprites/units/drone_walk_0.png assets/sprites/units/drone_walk_1.png assets/sprites/units/drone_walk_2.png assets/sprites/units/drone_walk_3.png tests/unit/test_keyed_frames.gd
git commit -m "feat: add magenta team-color key core to drone placeholder frames (SPI-1436)"
```

(These frames are LFS-tracked per the project's `.gitattributes`; `git add` stages them normally.)

---

### Task 4: Demo scene + in-engine verification

**Files:**
- Create: `scripts/dev/team_color_demo.gd`
- Create: `scenes/dev/team_color_demo.tscn`
- Test: `tests/unit/test_team_color_demo.gd`

**Interfaces:**
- Consumes: `TeamColors.color_for` (Task 1), `assets/shaders/team_color.gdshader` (Task 2), the keyed `drone_idle.png` (Task 3).
- Produces: a runnable dev scene that renders three swatches (teams 1, 2, neutral) added to the `"demo_swatches"` group, each a `Sprite2D` with a `ShaderMaterial` whose `team_color` differs.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_team_color_demo.gd`:

```gdscript
extends GutTest
## Verifies the team-color demo builds three distinct-colored swatches (SPI-1436).


func test_demo_creates_three_distinct_swatches() -> void:
	var demo := preload("res://scenes/dev/team_color_demo.tscn").instantiate()
	add_child_autofree(demo)
	await get_tree().process_frame
	var swatches := get_tree().get_nodes_in_group("demo_swatches")
	assert_eq(swatches.size(), 3, "demo should create 3 swatches")
	var colors := {}
	for s in swatches:
		var mat := (s as Sprite2D).material as ShaderMaterial
		colors[mat.get_shader_parameter("team_color")] = true
	assert_eq(colors.size(), 3, "the 3 swatches should use 3 distinct team colors")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL — `res://scenes/dev/team_color_demo.tscn` does not exist (load error).

- [ ] **Step 3: Write the demo script**

Create `scripts/dev/team_color_demo.gd`:

```gdscript
extends Node2D
## Dev-only visual proof for the team-color shader (SPI-1436). Renders the keyed
## drone sprite in team 1, team 2, and neutral colors side by side. Not wired into
## the game; run this scene directly and screenshot for issue verification.

const TEAM_COLOR_SHADER := preload("res://assets/shaders/team_color.gdshader")
const DRONE_TEXTURE := preload("res://assets/sprites/units/drone_idle.png")
const SPACING: float = 120.0
## Teams to display, left to right. 0 = neutral.
const SWATCH_TEAMS: Array[int] = [1, 2, 0]


func _ready() -> void:
	for i in range(SWATCH_TEAMS.size()):
		var team_id: int = SWATCH_TEAMS[i]
		var sprite := Sprite2D.new()
		sprite.texture = DRONE_TEXTURE
		sprite.scale = Vector2(3, 3)
		sprite.position = Vector2((i - 1) * SPACING, 0)
		var material := ShaderMaterial.new()
		material.shader = TEAM_COLOR_SHADER
		material.set_shader_parameter("team_color", TeamColors.color_for(team_id))
		sprite.material = material
		sprite.add_to_group("demo_swatches")
		add_child(sprite)
```

- [ ] **Step 4: Write the demo scene**

Create `scenes/dev/team_color_demo.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://team_color_demo"]

[ext_resource type="Script" path="res://scripts/dev/team_color_demo.gd" id="1_demo"]

[node name="TeamColorDemo" type="Node2D"]
script = ExtResource("1_demo")
```

- [ ] **Step 5: Import and run the test to verify it passes**

Run: `godot --headless --import`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. Confirm `test_team_color_demo.gd` ran (grep the log for it).

- [ ] **Step 6: Capture the in-engine screenshot (manual verification, AC)**

Run the demo scene with a display (not headless):
`godot --path . scenes/dev/team_color_demo.tscn`
Expected: three drone sprites — the left one's core green, the middle red, the right unchanged (neutral/magenta-luminance-white). Capture a screenshot; this is the "verified in-engine" evidence to attach to SPI-1436.

- [ ] **Step 7: Format, lint, commit**

```bash
gdformat scripts/dev/team_color_demo.gd
gdlint scripts/dev/team_color_demo.gd
git add scripts/dev/team_color_demo.gd scenes/dev/team_color_demo.tscn tests/unit/test_team_color_demo.gd
git commit -m "test: team-color demo scene for in-engine verification (SPI-1436)"
```

---

## Verification checklist (whole feature)

- [ ] Full suite green: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (baseline 247 tests + the new `test_team_colors`, `test_unit_team_color`, `test_keyed_frames`, `test_team_color_demo` tests all counted).
- [ ] `gdformat --check scripts/` and `gdlint scripts/` clean.
- [ ] Headless smoke of the real game scene has no SCRIPT ERROR: `godot --headless --quit-after 5 scenes/main/main.tscn` (units spawn, self-color, no crash).
- [ ] In-engine screenshot of the demo scene captured and attached to SPI-1436.
- [ ] Shader header records the KoBeWi-technique/MIT licensing note.
