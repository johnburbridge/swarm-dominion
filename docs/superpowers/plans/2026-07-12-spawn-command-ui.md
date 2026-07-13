# Spawn Command UI (SPI-1423) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a HUD spawn button that appears when a Mother is selected, shows the Drone's biomass cost, disables when unaffordable, and calls `MotherUnit.spawn_unit()` on click.

**Architecture:** A new `SpawnPanel` (`Control`) HUD component mirrors the existing `ResourceCounter`: it lives under the `UI` `CanvasLayer` and connects to autoload signals in `_ready`. It shows/hides on `SelectionManager.selection_changed` (tracking the first selected `MotherUnit`), reads the cost from a new `MotherUnit.get_spawn_cost()` accessor, and toggles the button's `disabled` from `ResourceManager.can_afford`, refreshing live on `EventBus.resources_changed`.

**Tech Stack:** Godot 4.7 (stable; CI pins 4.7.0), GDScript, GUT 9.5.0 for tests, gdformat/gdlint for style.

## Global Constraints

- **Engine/lang:** Godot 4.7 stable, GDScript with type hints on params/returns.
- **Cost is data-driven:** the button label and affordability use the cost the Mother loaded from `data/upgrade_costs.json`, read via `MotherUnit.get_spawn_cost()`. Do NOT hardcode `25` in production logic or in test assertions — tests read the expected cost from `mother.get_spawn_cost()` or from the data file.
- **Reuse existing seams:** `SelectionManager.selection_changed(selected_units: Array[UnitBase])`, `SelectionManager.get_selected_units()`, `EventBus.resources_changed(team_id, amount)`, `ResourceManager.can_afford(team_id, amount) -> bool`, and `MotherUnit.spawn_unit()`. Add no new signals.
- **Target the first selected Mother:** the panel acts on the first `MotherUnit` in the selection; one click spawns one Drone.
- **Affordability team:** use the selected Mother's `team_id` (not a hardcoded player id).
- **mouse_filter gotcha:** the panel root `Control` uses `mouse_filter = 2` (IGNORE) so its empty area never swallows map clicks; the `Button` uses `mouse_filter = 0` (STOP) to receive clicks.
- **Do NOT modify `scripts/main.gd`:** the temporary `KEY_B` debug hook is kept as-is per the story owner.
- **Style:** `gdformat` and `gdlint` must pass clean on every touched script before commit. gdlint requires class members ordered: constants → plain `var` → `@onready var` → functions.
- **Commits:** Atomic, conventional-commit messages, footer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **GUT gotchas:** (1) `.gutconfig.json` sets `dirs`, so `-gtest=` is ignored — run the whole suite and grep for the new filename + confirm the Tests count rose. (2) Reference a not-yet-existing production **class as a type** and the test file fails to parse, which GUT silently skips (false green) — so the test loads scenes by STRING PATH and never types anything as `SpawnPanel`; typed access to `MotherUnit.get_spawn_cost()` is safe only because Step 1 bootstraps that method first.

---

### Task 1: `SpawnPanel` component + `MotherUnit.get_spawn_cost()`

**Files:**
- Modify: `scripts/units/mother_unit.gd` (add `get_spawn_cost()`)
- Create: `scripts/ui/spawn_panel.gd`
- Create: `scenes/ui/spawn_panel.tscn`
- Create: `tests/unit/test_spawn_panel.gd`
- No change: `scripts/autoload/selection_manager.gd`, `scripts/autoload/resource_manager.gd`, `scripts/autoload/event_bus.gd`

**Interfaces:**
- Consumes: `SelectionManager.selection_changed(selected_units: Array[UnitBase])`, `SelectionManager.select_unit(unit)`, `SelectionManager.deselect_all()`; `EventBus.resources_changed(player_id: int, new_amount: int)`; `ResourceManager.can_afford(team_id: int, amount: int) -> bool`, `add_resources`, `get_resources`, `reset`; `MotherUnit.spawn_unit() -> UnitBase`; scenes `res://scenes/units/mother.tscn` (root `MotherUnit`), `res://scenes/units/drone.tscn` (root `UnitBase`, `unit_type == "drone"`).
- Produces: `MotherUnit.get_spawn_cost() -> int`; scene `res://scenes/ui/spawn_panel.tscn` with root `Control` (`class_name SpawnPanel`) named `SpawnPanel` and a child `Button` named `SpawnButton`. Task 2 relies on this scene existing.

- [ ] **Step 1: Bootstrap `get_spawn_cost()` so the test parses (as a failing stub)**

The test calls `mother.get_spawn_cost()` on a typed `MotherUnit`; that method must exist for the file to parse. Add it to `scripts/units/mother_unit.gd` as a deliberately-wrong stub (returns `-1`) so the accessor test goes RED. Insert it immediately after `is_auto_targetable()`:

```gdscript
## The biomass cost to spawn one Drone from this Mother (loaded from data).
func get_spawn_cost() -> int:
	return -1  # TDD stub — Step 4 returns the loaded _spawn_cost
```

- [ ] **Step 2: Write the failing tests**

Create `tests/unit/test_spawn_panel.gd` with the full content below:

```gdscript
extends GutTest
## Tests for the SpawnPanel HUD component (SPI-1423): a spawn button that appears
## while a Mother is selected, shows the data-driven Drone cost, greys out when the
## owning team can't afford one, and calls spawn_unit() on click.
##
## NOTE: load scenes by STRING PATH and never reference the `SpawnPanel` class as a
## type — at RED the script/scene don't exist, and referencing the type would make
## this file fail to PARSE (GUT silently skips an unparseable file — a false green).

const PLAYER_TEAM: int = 1

var _panel_scene: PackedScene
var _mother_scene: PackedScene
var _drone_scene: PackedScene


func before_all() -> void:
	_panel_scene = load("res://scenes/ui/spawn_panel.tscn")
	_mother_scene = load("res://scenes/units/mother.tscn")
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	ResourceManager.reset()
	SelectionManager.deselect_all()


func after_each() -> void:
	SelectionManager.deselect_all()


func _instantiate_panel() -> Control:
	var panel := _panel_scene.instantiate() as Control
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel


func _make_mother(tid: int) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = Vector2(400, 300)
	add_child_autofree(mother)
	return mother


func _make_drone(tid: int) -> UnitBase:
	var drone := _drone_scene.instantiate() as UnitBase
	drone.team_id = tid
	add_child_autofree(drone)
	return drone


func _count_player_drones() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("units"):
		if node is UnitBase and node.team_id == PLAYER_TEAM and node.unit_type == "drone":
			count += 1
	return count


func _free_spawned_drones() -> void:
	for node in get_tree().get_nodes_in_group("units"):
		if node is UnitBase and node.unit_type == "drone":
			node.queue_free()


# --- structure & visibility ---


func test_panel_has_spawn_button() -> void:
	var panel := await _instantiate_panel()
	assert_not_null(
		panel.get_node_or_null("SpawnButton"),
		"SpawnPanel should have a Button child named 'SpawnButton'"
	)


func test_hidden_when_nothing_selected() -> void:
	var panel := await _instantiate_panel()
	assert_false(panel.visible, "panel should be hidden with no selection")


func test_hidden_when_non_mother_selected() -> void:
	var panel := await _instantiate_panel()
	var drone := _make_drone(PLAYER_TEAM)
	SelectionManager.select_unit(drone)
	assert_false(panel.visible, "panel should stay hidden when only a Drone is selected")


func test_visible_when_mother_selected() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	assert_true(panel.visible, "panel should be visible when a Mother is selected")


func test_hidden_again_after_deselect() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	assert_true(panel.visible, "panel visible after selecting Mother")
	SelectionManager.deselect_all()
	assert_false(panel.visible, "panel should hide after deselect")


# --- cost display ---


func test_button_shows_data_driven_cost() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button != null:
		assert_eq(
			button.text,
			"Spawn Drone (%d)" % mother.get_spawn_cost(),
			"button should show the data-driven Drone cost"
		)


# --- affordability & spawn ---


func test_affordable_enables_and_click_spawns() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	ResourceManager.add_resources(PLAYER_TEAM, 100)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button == null:
		return
	assert_false(button.disabled, "button should be enabled when affordable")
	var before_biomass := ResourceManager.get_resources(PLAYER_TEAM)
	var before_drones := _count_player_drones()
	button.pressed.emit()
	assert_eq(_count_player_drones(), before_drones + 1, "clicking should produce a Drone")
	assert_eq(
		ResourceManager.get_resources(PLAYER_TEAM),
		before_biomass - mother.get_spawn_cost(),
		"clicking should spend the spawn cost"
	)
	_free_spawned_drones()


func test_unaffordable_disables_and_no_spawn() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	# team has 0 biomass (reset in before_each)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button == null:
		return
	assert_true(button.disabled, "button should be disabled when unaffordable")
	var units_before := get_tree().get_nodes_in_group("units").size()
	button.pressed.emit()  # even if forced, spawn_unit() self-guards
	assert_eq(ResourceManager.get_resources(PLAYER_TEAM), 0, "no biomass spent when unaffordable")
	assert_eq(
		get_tree().get_nodes_in_group("units").size(),
		units_before,
		"no Drone produced when unaffordable"
	)


func test_button_enables_live_when_biomass_added() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button == null:
		return
	assert_true(button.disabled, "button starts disabled (0 biomass)")
	ResourceManager.add_resources(PLAYER_TEAM, mother.get_spawn_cost())
	assert_false(button.disabled, "button should enable live once affordable")


# --- accessor ---


func test_mother_get_spawn_cost_returns_loaded_cost() -> void:
	var mother := _make_mother(PLAYER_TEAM)
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var expected := int(json.data["spawn_costs"]["drone"]["biomass"])
	assert_eq(mother.get_spawn_cost(), expected, "get_spawn_cost should return the loaded cost")
```

- [ ] **Step 3: Run the suite and confirm the new tests are collected and fail**

Run:
```bash
godot --headless --import 2>/dev/null; godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/spi1423-red.txt; grep -c "test_spawn_panel" /tmp/spi1423-red.txt
```
Expected: the run collects `test_spawn_panel.gd` (grep count ≥ 1 — proves it parsed, not silently skipped). The 9 panel tests fail/error (the scene `res://scenes/ui/spawn_panel.tscn` does not exist yet, so `load(...)` returns null and instantiation errors loudly per test), and `test_mother_get_spawn_cost_returns_loaded_cost` fails (`-1 != 25`). Confirm you see multiple failures in `test_spawn_panel`, not a clean green.

- [ ] **Step 4: Implement the accessor, the panel script, and the panel scene**

First, replace the stub in `scripts/units/mother_unit.gd` — change `get_spawn_cost()` to return the real cost:

```gdscript
## The biomass cost to spawn one Drone from this Mother (loaded from data).
func get_spawn_cost() -> int:
	return _spawn_cost
```

Create `scripts/ui/spawn_panel.gd`:

```gdscript
class_name SpawnPanel extends Control
## HUD command panel: shows a spawn button while a Mother is selected, greys it
## out when the owning team can't afford a Drone, and spawns on click.

var _mother: MotherUnit = null

@onready var _button: Button = $SpawnButton


func _ready() -> void:
	visible = false
	_button.pressed.connect(_on_spawn_pressed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	EventBus.resources_changed.connect(_on_resources_changed)


func _on_selection_changed(selected_units: Array[UnitBase]) -> void:
	_mother = _first_mother(selected_units)
	if _mother == null:
		visible = false
		return
	visible = true
	_refresh()


func _on_resources_changed(team_id: int, _amount: int) -> void:
	if visible and _mother != null and team_id == _mother.team_id:
		_refresh()


func _on_spawn_pressed() -> void:
	if is_instance_valid(_mother):
		_mother.spawn_unit()


func _refresh() -> void:
	var cost := _mother.get_spawn_cost()
	_button.text = "Spawn Drone (%d)" % cost
	_button.disabled = not ResourceManager.can_afford(_mother.team_id, cost)


func _first_mother(units: Array[UnitBase]) -> MotherUnit:
	for unit in units:
		if unit is MotherUnit:
			return unit
	return null
```

Create `scenes/ui/spawn_panel.tscn` (mirrors `resource_counter.tscn`; root hidden, bottom-left, IGNORE mouse; button fills the panel and STOPs the mouse):

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
offset_right = 200.0
offset_bottom = -10.0
grow_vertical = 0
mouse_filter = 2
visible = false
script = ExtResource("1_script")

[node name="SpawnButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
custom_minimum_size = Vector2(180, 40)
mouse_filter = 0
text = "Spawn Drone"
```

- [ ] **Step 5: Run the suite and confirm all green**

Run:
```bash
godot --headless --import 2>/dev/null; godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/spi1423-green.txt; grep -E "^Tests|Passing Tests|Failing|Errors" /tmp/spi1423-green.txt | tail -5
```
Expected: all tests pass, 0 failures, 0 errors, and the Tests count rose by 10 (the new file). Confirm `grep -c "test_spawn_panel" /tmp/spi1423-green.txt` ≥ 1.

- [ ] **Step 6: Format, lint, and commit**

Run:
```bash
gdformat scripts/units/mother_unit.gd scripts/ui/spawn_panel.gd tests/unit/test_spawn_panel.gd
gdlint scripts/units/mother_unit.gd scripts/ui/spawn_panel.gd
```
Expected: gdformat reports reformatted/unchanged with no error; gdlint prints `Success: no problems found`. If gdformat rewrites anything, re-run the suite (Step 5) to confirm still green.

```bash
git add scripts/units/mother_unit.gd scripts/ui/spawn_panel.gd scripts/ui/spawn_panel.gd.uid scenes/ui/spawn_panel.tscn tests/unit/test_spawn_panel.gd tests/unit/test_spawn_panel.gd.uid
git commit -m "feat: spawn command panel for a selected Mother (SPI-1423)

A SpawnPanel HUD Control appears when a Mother is selected, shows the
data-driven Drone cost via MotherUnit.get_spawn_cost(), disables the button
when the team can't afford one (live via resources_changed), and calls
spawn_unit() on click.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
(The `.uid` files are generated by Godot on import; include them if present. If `git add` of a `.uid` errors because it does not exist, drop it from the command.)

---

### Task 2: Wire `SpawnPanel` into `main.tscn`

**Files:**
- Modify: `scenes/main/main.tscn` (instance `SpawnPanel` under the `UI` `CanvasLayer`)
- Modify: `tests/unit/test_spawn_panel.gd` (append the real-scene integration test)

**Interfaces:**
- Consumes: `res://scenes/ui/spawn_panel.tscn` from Task 1; the existing `UI` `CanvasLayer` node in `main.tscn`.
- Produces: a `SpawnPanel` node at path `UI/SpawnPanel` in `main.tscn`.

- [ ] **Step 1: Write the failing integration test**

Append to `tests/unit/test_spawn_panel.gd`. It needs the main scene; add this to `before_all()` (so the loader is available), right after the existing `_drone_scene` load line:

```gdscript
	_main_scene = load("res://scenes/main/main.tscn")
```
and add the member declaration near the other scene vars (after `var _drone_scene: PackedScene`):

```gdscript
var _main_scene: PackedScene
```

Then append this test at the end of the file:

```gdscript
func test_main_scene_has_spawn_panel_under_ui_hidden() -> void:
	var main := _main_scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("UI/SpawnPanel") as Control
	assert_not_null(panel, "main.tscn should have a SpawnPanel at UI/SpawnPanel")
	if panel != null:
		assert_false(panel.visible, "SpawnPanel should be hidden on load (no selection)")
```

- [ ] **Step 2: Run the suite and confirm the new test fails**

Run:
```bash
godot --headless --import 2>/dev/null; godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/spi1423-task2-red.txt; grep -E "^Tests|Passing Tests|Failing|Errors" /tmp/spi1423-task2-red.txt | tail -5
```
Expected: exactly one failure — `test_main_scene_has_spawn_panel_under_ui_hidden` fails on `assert_not_null` because `main.tscn` has no `UI/SpawnPanel` yet. All other tests still pass.

- [ ] **Step 3: Instance `SpawnPanel` in `main.tscn`**

Edit `scenes/main/main.tscn`. (a) Bump the scene's `load_steps` in the first line from `6` to `7`. (b) Add an `ext_resource` for the panel scene, immediately after the `resource_counter.tscn` ext_resource line (`id="5_rescounter"`):

```
[ext_resource type="PackedScene" path="res://scenes/ui/spawn_panel.tscn" id="6_spawnpanel"]
```
(c) Add the node instance at the end of the file, after the `ResourceCounter` node line:

```
[node name="SpawnPanel" parent="UI" instance=ExtResource("6_spawnpanel")]
```

- [ ] **Step 4: Run the suite and confirm all green**

Run:
```bash
godot --headless --import 2>/dev/null; godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/spi1423-task2-green.txt; grep -E "^Tests|Passing Tests|Failing|Errors" /tmp/spi1423-task2-green.txt | tail -5
```
Expected: all tests pass, 0 failures, 0 errors (Tests count is one higher than end of Task 1).

- [ ] **Step 5: Manual verification (optional but recommended)**

Run the game (`godot --path . scenes/main/main.tscn`). Initially no spawn panel is visible. Click the player Mother — a "Spawn Drone (25)" button appears bottom-left, greyed out (0 biomass). Gather ≥ 25 biomass with a Drone, and the button un-greys; click it to spawn a Drone beside the Mother. Click empty ground to deselect — the panel hides. Confirm map clicks near (but not on) the button still command units (mouse_filter passthrough).

- [ ] **Step 6: Commit**

```bash
git add scenes/main/main.tscn tests/unit/test_spawn_panel.gd
git commit -m "feat: mount SpawnPanel on the HUD in main.tscn (SPI-1423)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Notes for the executor

- After the last task, dispatch the final whole-branch code review, then use superpowers:finishing-a-development-branch (open PR, review, fix loop).
- Do NOT touch `scripts/main.gd` — the `KEY_B` debug hook stays.
- If any `godot --headless --import` step prints import chatter to stderr, that is normal; `2>/dev/null` suppresses it. Do not treat import output as a failure.
