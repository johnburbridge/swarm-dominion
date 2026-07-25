# Mother Rally Point Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player set a rally point on a Mother so units spawned from it automatically walk to a chosen location instead of piling up in the fan ring.

**Architecture:** Rally state lives on `MotherUnit` (the owner of both the point and its on-map marker). A new pure-visual `RallyMarker` (Node2D, drawn ring+crosshair) is a world-space (`top_level`) child of the Mother, shown only while the Mother is selected and has an explicit rally. `main.gd` supplies the interaction: an arming flag (`_rally_set_pending`) set by either the **R** hotkey (guarded by player-Mother selection) or the SpawnPanel's new **Set Rally** button (via a `rally_set_requested` signal); the next left-click on the map commits the point. `spawn_unit()` sends each new drone to `get_effective_rally()`.

**Tech Stack:** Godot 4.7 (stable), GDScript, GUT 9.5.0, gdtoolkit (gdformat/gdlint).

**Source spec:** `docs/superpowers/specs/2026-07-23-mother-rally-point-design.md`

## Global Constraints

- **Single source of truth:** `MotherUnit.get_effective_rally()` returns the explicit rally if set, else `position + DEFAULT_RALLY_OFFSET`; every spawn path uses it.
- **`DEFAULT_RALLY_OFFSET = Vector2(0, 96)`** — directly below the Mother (verbatim value; tests pin the literal `Vector2(0, 96)`).
- **Right-click is NOT used for rally** — it already moves the mobile Mother. Rally is armed, then committed by the next **left**-click.
- **`set_rally` input action = R** (keycode 82). WASD camera and A attack-move must remain unchanged.
- **Marker is drawn, not an art asset** — `RallyMarker._draw()` in the team color; no PNG dependency.
- **Marker lifecycle:** visible only when `selected AND has explicit rally`; deselect hides but retains the point; the marker is a child node so it frees with the Mother on death.
- **GDScript conventions:** type hints on all params/returns; `UPPER_SNAKE_CASE` consts; leading `_` for private; signals declared at top of class; regular `var` before `@onready var`; consts before vars.
- **New `class_name` (`RallyMarker`) needs `godot --headless --import`** before any other script or test can resolve the type.
- **GUT false-green:** a parse/compile-errored test file is silently skipped while the suite still reports "All tests passed." After each GREEN, grep the run log to confirm the new/edited test file actually ran and the pass count rose. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (`-gtest=` is ignored when `.gutconfig.json` sets `dirs`). Baseline on this branch: **255 passing**.
- **TDD-with-typed-GDScript note:** referencing a not-yet-defined typed method/const (e.g. `mother.get_effective_rally()`) is a *compile* error that halts the whole file, so RED for a new typed symbol appears as a compile error naming the missing symbol — that IS the expected RED, not an assertion failure. New `class_name` types are referenced in tests via `load("res://.../file.gd")` (string path), never by the bare type name, so the test file still parses at RED.
- **gdformat/gdlint must be clean** before every commit: `gdformat scripts/ tests/ tools/` and `gdlint scripts/`.
- **Git over SSH only** (repo-local `core.sshCommand` is set); commits are atomic + conventional; branch is `spi-1424-mother-rally-point` (already checked out); never merge to main directly.

## File Structure

| File | Responsibility |
|------|----------------|
| `scripts/ui/rally_marker.gd` | **New.** `RallyMarker` — pure-visual Node2D drawing a ring+crosshair in a team color. |
| `tests/unit/test_rally_marker.gd` | **New.** RallyMarker API (color storage, Node2D, draws in-tree without error). |
| `scripts/units/mother_unit.gd` | **Modify.** Rally state, `set_rally_point`/`has_rally`/`get_rally_point`/`get_effective_rally`, marker create + `set_selected` override, spawn-move. |
| `tests/unit/test_mother_rally.gd` | **New.** Default/explicit rally, spawn targeting, marker visibility rules. |
| `scripts/ui/spawn_panel.gd` | **Modify.** `rally_set_requested` signal + RallyButton wiring. |
| `scenes/ui/spawn_panel.tscn` | **Modify.** Add `RallyButton`; widen panel; keep `SpawnButton` a direct child. |
| `tests/unit/test_spawn_panel.gd` | **Modify (extend).** RallyButton exists, emits the signal, stays enabled regardless of cost. |
| `scripts/main.gd` | **Modify.** `_rally_set_pending`, `_spawn_panel` ref, arm via R + panel signal, consume next left-click → set rally. |
| `project.godot` | **Modify.** New `set_rally` input action bound to R. |
| `tests/unit/test_main_rally.gd` | **New.** Action exists+bound to R; panel signal arms; hotkey arm requires selected player Mother; `_issue_set_rally` sets selected Mothers' rally. |

---

### Task 1: RallyMarker (drawn rally-point visual)

**Files:**
- Create: `scripts/ui/rally_marker.gd`
- Test: `tests/unit/test_rally_marker.gd`

**Interfaces:**
- Consumes: nothing (pure Node2D).
- Produces: `class_name RallyMarker extends Node2D`; `set_team_color(color: Color) -> void` (stores color, `queue_redraw()`); private `_color: Color` (default `Color.WHITE`); consts `RING_RADIUS`, `CROSSHAIR_ARM`, `LINE_WIDTH`, `RING_SEGMENTS`. Used by `MotherUnit` (Task 2).

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_rally_marker.gd`. Reference the script by **string path** (not the `RallyMarker` type) so the file parses at RED:

```gdscript
extends GutTest
## Tests for RallyMarker (SPI-1424): a purely visual Node2D that stores a team
## color and draws a ring + crosshair. The script is loaded by STRING PATH (never
## the `RallyMarker` class name) so this file still parses before the script exists.

const RALLY_MARKER_PATH := "res://scripts/ui/rally_marker.gd"


func _make_marker() -> Node2D:
	var script: GDScript = load(RALLY_MARKER_PATH)
	return script.new() as Node2D


func test_is_node2d() -> void:
	var marker := _make_marker()
	autofree(marker)
	assert_true(marker is Node2D, "RallyMarker should extend Node2D")


func test_default_color_is_white() -> void:
	var marker := _make_marker()
	autofree(marker)
	assert_eq(marker._color, Color.WHITE, "color should default to white before it is set")


func test_set_team_color_stores_color() -> void:
	var marker := _make_marker()
	autofree(marker)
	marker.set_team_color(Color(0.3, 0.85, 0.35))
	assert_eq(marker._color, Color(0.3, 0.85, 0.35), "set_team_color should store the color")


func test_draws_without_error_in_tree() -> void:
	var marker := _make_marker()
	marker.set_team_color(Color(0.9, 0.3, 0.3))
	add_child_autofree(marker)
	await get_tree().process_frame
	assert_true(is_instance_valid(marker), "marker should draw in-tree without error")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -A3 test_rally_marker`
Expected: the tests error/fail because `load("res://scripts/ui/rally_marker.gd")` returns `null` (script absent) → `null.new()` fails. RED confirmed.

- [ ] **Step 3: Create the RallyMarker script**

Create `scripts/ui/rally_marker.gd`:

```gdscript
class_name RallyMarker extends Node2D
## Purely visual rally-point marker (SPI-1424): a small ring + crosshair drawn in
## a team's color via _draw(). A MotherUnit instantiates one as a world-space
## (top_level) child to show where its spawned units will rally. No game logic.

## Radius of the drawn ring, in pixels.
const RING_RADIUS: float = 10.0
## Half-length of each crosshair arm, in pixels.
const CROSSHAIR_ARM: float = 6.0
## Stroke width for the ring and crosshair.
const LINE_WIDTH: float = 2.0
## Segment count approximating the ring in draw_arc.
const RING_SEGMENTS: int = 24

var _color: Color = Color.WHITE


## Sets the marker's tint (the owning team's color) and requests a redraw.
func set_team_color(color: Color) -> void:
	_color = color
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, RING_SEGMENTS, _color, LINE_WIDTH)
	draw_line(Vector2(-CROSSHAIR_ARM, 0), Vector2(CROSSHAIR_ARM, 0), _color, LINE_WIDTH)
	draw_line(Vector2(0, -CROSSHAIR_ARM), Vector2(0, CROSSHAIR_ARM), _color, LINE_WIDTH)
```

- [ ] **Step 4: Import so the new class_name resolves**

Run: `godot --headless --import`
Expected: completes without fatal errors (import warnings are OK).

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -A3 test_rally_marker`
Expected: `test_rally_marker.gd` runs; 4/4 assertions pass. Also confirm the overall pass count rose (255 → 259).

- [ ] **Step 6: Format, lint, commit**

```bash
gdformat scripts/ui/rally_marker.gd tests/unit/test_rally_marker.gd
gdlint scripts/ui/rally_marker.gd
git add scripts/ui/rally_marker.gd tests/unit/test_rally_marker.gd
git commit -m "feat(ui): add RallyMarker drawn rally-point visual (SPI-1424)"
```

---

### Task 2: MotherUnit rally state, marker, and spawn-move

**Files:**
- Modify: `scripts/units/mother_unit.gd`
- Test: `tests/unit/test_mother_rally.gd`

**Interfaces:**
- Consumes: `RallyMarker` (Task 1) — `RallyMarker.new()`, `set_team_color(Color)`; `TeamColors.color_for(team_id) -> Color`; `UnitBase.set_selected(selected: bool)`, `UnitBase.move_to(target: Vector2)`, `UnitBase._is_selected`.
- Produces: `const DEFAULT_RALLY_OFFSET := Vector2(0, 96)`; `set_rally_point(pos: Vector2) -> void`; `has_rally() -> bool`; `get_rally_point() -> Vector2`; `get_effective_rally() -> Vector2`; private `_rally_marker: RallyMarker`. Used by `main.gd` (Task 4).

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_mother_rally.gd`. `MotherUnit`/`UnitBase` already exist as types, so reference them directly; the default-rally literal `Vector2(0, 96)` is pinned in-test:

```gdscript
extends GutTest
## Tests for Mother rally points (SPI-1424): the default effective rally sits just
## below the Mother; an explicit rally is recorded and returned; spawned drones walk
## to the effective rally; the marker is visible only when the Mother is selected AND
## has an explicit rally (deselect retains the point).

var _mother_scene: PackedScene


func before_all() -> void:
	_mother_scene = load("res://scenes/units/mother.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _create_mother(tid: int, pos: Vector2) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = pos
	add_child_autofree(mother)
	return mother


func test_no_rally_by_default() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	assert_false(mother.has_rally(), "a fresh Mother should have no explicit rally")


func test_effective_rally_defaults_below_mother() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	assert_eq(
		mother.get_effective_rally(),
		Vector2(400, 300) + Vector2(0, 96),
		"with no rally set, effective rally is just below the Mother"
	)


func test_set_rally_point_records_point() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	assert_true(mother.has_rally(), "has_rally should be true after set_rally_point")
	assert_eq(mother.get_rally_point(), Vector2(700, 500), "get_rally_point returns the set point")
	assert_eq(
		mother.get_effective_rally(), Vector2(700, 500), "effective rally is the explicit point"
	)


func test_spawned_drone_moves_to_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	mother.set_rally_point(Vector2(900, 700))
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_not_null(drone, "spawn should succeed")
	assert_eq(
		drone._target_position, Vector2(900, 700), "spawned drone should target the rally point"
	)
	assert_eq(drone._state, UnitBase.UnitState.MOVING, "spawned drone should be moving to rally")


func test_spawned_drone_moves_to_default_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_not_null(drone, "spawn should succeed")
	assert_eq(
		drone._target_position,
		Vector2(400, 300) + Vector2(0, 96),
		"with no rally, spawned drone should target the default just below the Mother"
	)


func test_marker_hidden_when_unselected() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	assert_false(mother._rally_marker.visible, "marker should be hidden while the Mother is unselected")


func test_marker_visible_when_selected_with_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	mother.set_selected(true)
	assert_true(mother._rally_marker.visible, "marker should be visible when selected and rally set")


func test_marker_hidden_when_selected_without_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_selected(true)
	assert_false(
		mother._rally_marker.visible, "marker should stay hidden when selected with no rally set"
	)


func test_deselect_hides_marker_but_retains_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	mother.set_selected(true)
	mother.set_selected(false)
	assert_false(mother._rally_marker.visible, "marker should hide after deselect")
	assert_true(mother.has_rally(), "rally should be retained after deselect")
	assert_eq(mother.get_rally_point(), Vector2(700, 500), "rally point should be retained after deselect")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -A3 test_mother_rally`
Expected: compile error naming a missing symbol (e.g. `Function "has_rally()" not found` / `Invalid access to constant`), so `test_mother_rally.gd` does not run. That compile error IS the expected RED for new typed methods.

- [ ] **Step 3: Add the constant and rally state**

In `scripts/units/mother_unit.gd`, after the `SPAWN_ANGLE_STEP` const block (line 19) add:

```gdscript
## Offset from the Mother's center for the default rally when no explicit point is
## set: directly below, clear of the Mother's body (radius 32) plus a Drone's radius,
## so spawned Drones disperse instead of stacking on the Mother.
const DEFAULT_RALLY_OFFSET: Vector2 = Vector2(0, 96)
```

Then, after the existing `_spawn_count` var (line 26) add:

```gdscript
## Explicit rally point (world space); meaningful only when _has_rally is true.
var _rally_point: Vector2 = Vector2.ZERO
## Whether the player has set an explicit rally (vs. the just-below-Mother default).
var _has_rally: bool = false
## World-space (top_level) visual for the rally point; a child so it frees with the Mother.
var _rally_marker: RallyMarker = null
```

- [ ] **Step 4: Create the marker in _ready and add the rally API + selection override**

Replace the existing `_ready()` (lines 33-35) with:

```gdscript
func _ready() -> void:
	super._ready()
	_load_spawn_cost()
	_setup_rally_marker()


func _setup_rally_marker() -> void:
	_rally_marker = RallyMarker.new()
	# top_level so the marker's transform is world-space and the rally point stays
	# put when the (mobile) Mother moves.
	_rally_marker.top_level = true
	_rally_marker.set_team_color(TeamColors.color_for(team_id))
	_rally_marker.visible = false
	add_child(_rally_marker)


## Overrides UnitBase.set_selected to also toggle the rally marker: visible only
## when the Mother is selected AND has an explicit rally. Deselecting hides the
## marker but keeps _rally_point/_has_rally.
func set_selected(selected: bool) -> void:
	super.set_selected(selected)
	if _rally_marker != null:
		_rally_marker.visible = selected and _has_rally


## Records an explicit rally point, moves the marker there, and shows it if the
## Mother is currently selected.
func set_rally_point(pos: Vector2) -> void:
	_rally_point = pos
	_has_rally = true
	if _rally_marker != null:
		_rally_marker.global_position = pos
		_rally_marker.visible = _is_selected


func has_rally() -> bool:
	return _has_rally


func get_rally_point() -> Vector2:
	return _rally_point


## Single source of truth for where a spawned Drone goes: the explicit rally if
## set, else just below the Mother (DEFAULT_RALLY_OFFSET).
func get_effective_rally() -> Vector2:
	if _has_rally:
		return _rally_point
	return position + DEFAULT_RALLY_OFFSET
```

- [ ] **Step 5: Send spawned drones to the effective rally**

In `spawn_unit()`, immediately after `get_parent().add_child(drone)` (line 60) and before `EventBus.unit_spawned.emit(drone)`, insert:

```gdscript
	drone.move_to(get_effective_rally())
```

- [ ] **Step 6: Import and run the test to verify it passes**

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -A3 test_mother_rally
```
Expected: `test_mother_rally.gd` runs; 9/9 assertions pass. Confirm the overall pass count rose (259 → 268) and no prior test regressed.

- [ ] **Step 7: Format, lint, commit**

```bash
gdformat scripts/units/mother_unit.gd tests/unit/test_mother_rally.gd
gdlint scripts/units/mother_unit.gd
git add scripts/units/mother_unit.gd tests/unit/test_mother_rally.gd
git commit -m "feat(units): Mother rally point state, marker, and spawn-move (SPI-1424)"
```

---

### Task 3: SpawnPanel "Set Rally" button

**Files:**
- Modify: `scripts/ui/spawn_panel.gd`
- Modify: `scenes/ui/spawn_panel.tscn`
- Test: `tests/unit/test_spawn_panel.gd` (extend)

**Interfaces:**
- Consumes: existing `SpawnPanel` visibility logic (panel shown only when a Mother is selected).
- Produces: `signal rally_set_requested`; a `RallyButton` Button child (direct child of the panel) whose `pressed` emits `rally_set_requested`. Consumed by `main.gd` (Task 4). `SpawnButton` remains a direct child at `$SpawnButton` (existing tests depend on the path).

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_spawn_panel.gd` (before the final `test_main_scene_has_spawn_panel_under_ui_hidden`, or at end of file):

```gdscript
# --- rally button (SPI-1424) ---


func test_panel_has_rally_button() -> void:
	var panel := await _instantiate_panel()
	assert_not_null(
		panel.get_node_or_null("RallyButton"),
		"SpawnPanel should have a Button child named 'RallyButton'"
	)


func test_rally_button_emits_request() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	watch_signals(panel)
	var button := panel.get_node_or_null("RallyButton") as Button
	assert_not_null(button, "RallyButton should exist")
	if button == null:
		return
	button.pressed.emit()
	assert_signal_emitted(
		panel, "rally_set_requested", "pressing RallyButton should emit rally_set_requested"
	)


func test_rally_button_enabled_regardless_of_cost() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	# team has 0 biomass (before_each reset); rally is free, so the button stays enabled
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("RallyButton") as Button
	assert_not_null(button, "RallyButton should exist")
	if button != null:
		assert_false(
			button.disabled, "RallyButton should be enabled whenever a Mother is selected"
		)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -E "test_rally_button|test_panel_has_rally"`
Expected: the three new tests fail — `RallyButton` node is absent and `rally_set_requested` is not a signal on the panel yet. RED confirmed.

- [ ] **Step 3: Add RallyButton to the scene and widen the panel**

Replace the entire contents of `scenes/ui/spawn_panel.tscn` with (widens the panel to 390px and adds `RallyButton` beside `SpawnButton`; both stay direct children with `mouse_filter = 0` so each consumes its own click):

```
[gd_scene load_steps=2 format=3 uid="uid://spawn_panel_scene"]

[ext_resource type="Script" path="res://scripts/ui/spawn_panel.gd" id="1_script"]

[node name="SpawnPanel" type="Control"]
layout_mode = 3
anchors_preset = 2
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = -60.0
offset_right = 400.0
offset_bottom = -10.0
grow_vertical = 0
mouse_filter = 2
visible = false
script = ExtResource("1_script")

[node name="SpawnButton" type="Button" parent="."]
layout_mode = 1
offset_right = 180.0
offset_bottom = 40.0
custom_minimum_size = Vector2(180, 40)
mouse_filter = 0
text = "Spawn Drone"

[node name="RallyButton" type="Button" parent="."]
layout_mode = 1
offset_left = 190.0
offset_right = 370.0
offset_bottom = 40.0
custom_minimum_size = Vector2(180, 40)
mouse_filter = 0
text = "Set Rally"
```

- [ ] **Step 4: Wire the signal in the script**

Replace `scripts/ui/spawn_panel.gd` lines 1-14 (docstring through end of `_ready`) with:

```gdscript
class_name SpawnPanel extends Control
## HUD command panel: shows a spawn button while a Mother is selected, greys it
## out when the owning team can't afford a Drone, spawns on click, and offers a
## "Set Rally" button that requests rally-placement arming (SPI-1424).

signal rally_set_requested

var _mother: MotherUnit = null

@onready var _button: Button = $SpawnButton
@onready var _rally_button: Button = $RallyButton


func _ready() -> void:
	visible = false
	_button.pressed.connect(_on_spawn_pressed)
	_rally_button.pressed.connect(_on_rally_pressed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
```

Then add this handler (place it after `_on_spawn_pressed`, near line 34):

```gdscript
func _on_rally_pressed() -> void:
	rally_set_requested.emit()
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -E "test_rally_button|test_panel_has_rally"`
Expected: all three new tests pass. Also grep `test_spawn_panel` to confirm the whole file still runs and no existing SpawnButton test regressed; confirm overall pass count rose (268 → 271).

- [ ] **Step 6: Format, lint, commit**

```bash
gdformat scripts/ui/spawn_panel.gd tests/unit/test_spawn_panel.gd
gdlint scripts/ui/spawn_panel.gd
git add scripts/ui/spawn_panel.gd scenes/ui/spawn_panel.tscn tests/unit/test_spawn_panel.gd
git commit -m "feat(ui): add Set Rally button to SpawnPanel (SPI-1424)"
```

---

### Task 4: main.gd interaction wiring + set_rally input action

**Files:**
- Modify: `project.godot` (add `set_rally` action after `attack_move`, ~line 59)
- Modify: `scripts/main.gd`
- Test: `tests/unit/test_main_rally.gd`

**Interfaces:**
- Consumes: `MotherUnit.set_rally_point(pos: Vector2)` (Task 2); `SpawnPanel.rally_set_requested` (Task 3); `SelectionManager.get_selected_units()`; the `set_rally` input action; the `UI/SpawnPanel` node in `main.tscn`.
- Produces: `main._rally_set_pending: bool`; `_on_rally_set_requested()`, `_arm_rally_from_hotkey()`, `_issue_set_rally(pos: Vector2)`; `@onready _spawn_panel: SpawnPanel`.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_main_rally.gd`:

```gdscript
extends GutTest
## Tests for main.gd rally wiring (SPI-1424): the set_rally input action exists and
## is bound to R; the SpawnPanel's rally_set_requested arms placement; arming via the
## hotkey requires a selected player Mother; and _issue_set_rally sets the rally on
## every selected player Mother at the given position.

const PLAYER_TEAM: int = 1

var _main_scene: PackedScene
var _mother_scene: PackedScene


func before_all() -> void:
	_main_scene = load("res://scenes/main/main.tscn")
	_mother_scene = load("res://scenes/units/mother.tscn")


func before_each() -> void:
	ResourceManager.reset()
	SelectionManager.deselect_all()


func after_each() -> void:
	SelectionManager.deselect_all()


func _make_main() -> Node2D:
	var main := _main_scene.instantiate() as Node2D
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _make_mother(tid: int) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = Vector2(400, 300)
	add_child_autofree(mother)
	return mother


func test_set_rally_action_bound_to_r() -> void:
	assert_true(InputMap.has_action("set_rally"), "project should define a set_rally action")
	var found := false
	for ev in InputMap.action_get_events("set_rally"):
		if ev is InputEventKey and ev.keycode == KEY_R:
			found = true
	assert_true(found, "set_rally should be bound to the R key")


func test_panel_signal_arms_rally() -> void:
	var main := await _make_main()
	assert_false(main._rally_set_pending, "rally should not be armed initially")
	main._spawn_panel.rally_set_requested.emit()
	assert_true(main._rally_set_pending, "the panel request should arm rally placement")


func test_hotkey_arm_requires_player_mother_selected() -> void:
	var main := await _make_main()
	main._arm_rally_from_hotkey()
	assert_false(main._rally_set_pending, "R with no Mother selected should not arm")
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	main._arm_rally_from_hotkey()
	assert_true(main._rally_set_pending, "R with a player Mother selected should arm")


func test_issue_set_rally_sets_selected_mother_rally() -> void:
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	main._issue_set_rally(Vector2(950, 640))
	assert_true(mother.has_rally(), "issue_set_rally should set the selected Mother's rally")
	assert_eq(
		mother.get_rally_point(), Vector2(950, 640), "rally point should match the issued position"
	)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -A3 test_main_rally`
Expected: compile error / failures — `set_rally` action absent, and `_rally_set_pending`/`_arm_rally_from_hotkey`/`_issue_set_rally`/`_spawn_panel` are missing on `main`. RED confirmed.

- [ ] **Step 3: Add the set_rally input action**

In `project.godot`, immediately after the `attack_move={...}` block (ends line 59) and before `camera_up`, insert:

```
set_rally={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":82,"physical_keycode":82,"key_label":82,"unicode":114,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 4: Add the arming field and panel reference**

In `scripts/main.gd`, after `var _attack_move_pending: bool = false` (line 14) add:

```gdscript
var _rally_set_pending: bool = false
```

After `@onready var _minimap: Minimap = $UI/Minimap` (line 21) add:

```gdscript
@onready var _spawn_panel: SpawnPanel = $UI/SpawnPanel
```

- [ ] **Step 5: Connect the panel signal in _ready**

In `main.gd` `_ready()` (lines 24-27), add the connection after `_minimap.set_camera(_camera)`:

```gdscript
	_spawn_panel.rally_set_requested.connect(_on_rally_set_requested)
```

- [ ] **Step 6: Arm from the hotkey in _unhandled_input**

In `main.gd` `_unhandled_input`, insert a new `elif` between the `attack_move` branch (lines 64-65) and the `elif event is InputEventKey ...` branch (line 66):

```gdscript
		elif event.is_action_pressed("set_rally"):
			_arm_rally_from_hotkey()
```

(It must come **before** the generic `InputEventKey` branch, or that branch would swallow the R key and the rally branch would never run.)

- [ ] **Step 7: Consume the armed click in _handle_click_select**

In `main.gd` `_handle_click_select()`, add this block at the very top of the function (before the `_attack_move_pending` check on line 126):

```gdscript
	if _rally_set_pending:
		_rally_set_pending = false
		_issue_set_rally(get_global_mouse_position())
		return
```

- [ ] **Step 8: Add the rally handler methods**

In `main.gd`, add these methods after `_issue_attack_move()` (ends line 152):

```gdscript
func _on_rally_set_requested() -> void:
	_rally_set_pending = true


func _arm_rally_from_hotkey() -> void:
	for unit in SelectionManager.get_selected_units():
		if is_instance_valid(unit) and unit is MotherUnit and unit.team_id == PLAYER_TEAM_ID:
			_rally_set_pending = true
			return


func _issue_set_rally(pos: Vector2) -> void:
	for unit in SelectionManager.get_selected_units():
		if is_instance_valid(unit) and unit is MotherUnit and unit.team_id == PLAYER_TEAM_ID:
			unit.set_rally_point(pos)
```

- [ ] **Step 9: Import and run the test to verify it passes**

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -A3 test_main_rally
```
Expected: `test_main_rally.gd` runs; 4/4 assertions pass. Confirm overall pass count rose (271 → 275... i.e. +4 over Task 3) and no prior test regressed.

- [ ] **Step 10: Run the full suite once to confirm no regressions**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20`
Expected: all tests pass; total is the baseline 255 + 20 new (4 marker + 9 mother + 3 panel + 4 main) = **275** passing (adjust if any count differs and investigate before committing).

- [ ] **Step 11: Format, lint, commit**

```bash
gdformat scripts/main.gd tests/unit/test_main_rally.gd
gdlint scripts/main.gd
git add project.godot scripts/main.gd tests/unit/test_main_rally.gd
git commit -m "feat(main): arm and place Mother rally via R hotkey and Set Rally button (SPI-1424)"
```

---

## Manual verification (in-engine, after all tasks)

1. `godot --path . scenes/main/main.tscn`
2. Select the player Mother → the HUD shows **[Spawn Drone] [Set Rally]**.
3. Press **R**, then left-click on the map → a ring+crosshair marker appears in the player team color at the click.
4. Click **Set Rally**, then left-click elsewhere → the marker moves to the new point (button click did not double as placement).
5. Spawn a Drone → it walks from the fan ring to the rally marker.
6. Deselect the Mother → the marker hides. Re-select → it reappears at the same point.
7. Move the Mother → the marker stays where it was placed (world-space). Spawn again → new Drone still targets it.
8. With no Mother selected, press **R** → nothing arms (next click just selects normally).

## Self-Review

**Spec coverage:**
- Dual arming (R + Set Rally button, shared `_rally_set_pending`) → Task 3 (signal) + Task 4 (both arm paths). ✅
- Default rally `Vector2(0, 96)` via `get_effective_rally()` → Task 2 (const + method + pinned literal in tests). ✅
- Drawn ring+crosshair marker in team color, no art asset → Task 1. ✅
- Marker as world-space `top_level` child, freed with Mother → Task 2 (`_setup_rally_marker`). ✅
- Marker visible only when selected AND has rally; deselect retains point → Task 2 (`set_selected` override + retention test). ✅
- `spawn_unit` sends drone to effective rally → Task 2 Step 5. ✅
- `set_rally` action = R (82); WASD/A untouched → Task 4 Step 3 (inserted alongside, existing actions unchanged). ✅
- Right-click unchanged (still moves Mother) → no change to `_handle_command`; rally consumes the **left**-click path only. ✅
- Multiple Mothers get the same rally, each its own marker → Task 4 `_issue_set_rally` loops all selected player Mothers; each Mother owns its marker. ✅
- Button consumes its own click (mouse_filter=0) → Task 3 scene keeps `RallyButton mouse_filter = 0`. ✅

**Placeholder scan:** none — every code step shows complete code; every command has an expected result.

**Type consistency:** `get_effective_rally`/`set_rally_point`/`has_rally`/`get_rally_point`/`_rally_marker`/`_rally_set_pending`/`_arm_rally_from_hotkey`/`_issue_set_rally`/`_on_rally_set_requested`/`rally_set_requested`/`RallyMarker.set_team_color`/`DEFAULT_RALLY_OFFSET` are named identically across the tasks that define and consume them. `SpawnButton` stays a direct child (existing tests preserved). ✅
