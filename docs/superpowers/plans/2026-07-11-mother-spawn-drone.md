# Mother Spawns a Drone (SPI-1422) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `MotherUnit.spawn_unit()`, which charges the team's biomass and creates a Level 1 Drone clear of the Mother, announcing it via `EventBus.unit_spawned`.

**Architecture:** All spawn logic lives on `MotherUnit` (a `UnitBase` subclass). It reads the Drone spawn cost from `data/upgrade_costs.json` at ready, charges biomass through the existing atomic `ResourceManager.spend_resources()`, instantiates `drone.tscn` as a sibling in the Mother's parent, and places it on a deterministic ring. A temporary `KEY_B` binding in the harness (`main.gd`) drives it for manual playtest.

**Tech Stack:** Godot 4.7 (stable; CI pins 4.7.0), GDScript, GUT 9.5.0 for tests, gdformat/gdlint for style.

## Global Constraints

- **Engine/lang:** Godot 4.7 stable, GDScript with type hints on params and returns.
- **Deterministic:** No `randf`/random anywhere in spawn logic — placement uses an integer counter (lockstep-safe, per the PRD networking goal).
- **Data-driven cost:** The Drone spawn cost is read from `data/upgrade_costs.json` at `spawn_costs.drone.biomass` (currently `25`). Changing that value must change the charge with no code change. Do NOT hardcode `25` in production logic or in test assertions — read it from data.
- **Reuse, don't add:** Charge via `ResourceManager.spend_resources(team_id, amount)` (returns `false` and deducts nothing when unaffordable). Announce via the existing `EventBus.unit_spawned(unit)` signal. Do not add a new failure signal.
- **Result contract:** `spawn_unit() -> UnitBase` returns the new Drone on success, `null` on insufficient biomass.
- **Placement:** Drone appears at distance `SPAWN_RADIUS = 60.0` from the Mother (clears the Mother's 32 px body + Drone's 16 px radius). Successive spawns step by `SPAWN_ANGLE_STEP = TAU / 8.0`. The Drone is added to the Mother's parent (a sibling), never as a child of the Mother.
- **Style:** `gdformat` and `gdlint` must pass clean on every touched script before commit. gdlint requires class members ordered constants → vars → functions.
- **Commits:** Atomic, conventional-commit messages, footer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **GUT gotcha:** `.gutconfig.json` sets `dirs`, so `-gtest=` is ignored — run the whole suite and grep for the new filename + confirm the Scripts/Tests counts rose (a parse-errored test file is silently skipped and still reports "All tests passed").

---

### Task 1: `MotherUnit.spawn_unit()` + spawn-cost loader

**Files:**
- Modify: `scripts/units/mother_unit.gd` (add spawn constants/state, `_ready` override, `_load_spawn_cost()`, `spawn_unit()`)
- Create: `tests/unit/test_mother_spawn_drone.gd`
- Modify: `tests/unit/test_mother_spawn.gd` (append one real-scene integration test)
- No change: `data/upgrade_costs.json`, `scripts/autoload/event_bus.gd`, `scripts/autoload/resource_manager.gd`

**Interfaces:**
- Consumes: `ResourceManager.spend_resources(team_id: int, amount: int) -> bool` (atomic — false if unaffordable), `ResourceManager.add_resources(team_id, amount)`, `ResourceManager.get_resources(team_id) -> int`, `ResourceManager.reset()`; `EventBus.unit_spawned(unit: Node)`; `UnitBase` members `unit_type`, `team_id`, `position`, `is_in_group("units")`; scene `res://scenes/units/drone.tscn` (root `UnitBase`, `unit_type == "drone"`, collision radius 16); the Mother scene `res://scenes/units/mother.tscn` (root `MotherUnit`, body radius 32).
- Produces: `MotherUnit.spawn_unit() -> UnitBase` (returns the new Drone or `null`); member `var _spawn_cost: int` (loaded from data); member `var _spawn_count: int`. Task 2 relies on `spawn_unit()` existing.

- [ ] **Step 1: Bootstrap minimal stubs so the test file parses**

GDScript static analysis rejects a test that references a method/member not present on the typed `MotherUnit`, and GUT silently skips an unparseable file (false green). Add just enough to `scripts/units/mother_unit.gd` so the tests parse but fail on behavior. Insert the constants/vars block and stub between the class docstring and `_init()`, keeping members before functions:

```gdscript
class_name MotherUnit extends UnitBase
## The Mother: a large, slow, high-HP command unit. It cannot harvest and cannot
## auto-attack — both fall out of the "mother" stats entry having no
## harvest_speed / attack_range (they default to 0, so harvest_at() no-ops and
## no attack Area2D is built). It is also never auto-targeted by enemies. Later
## M4 stories add spawning (SPI-1422) and rally points (SPI-1424) here.

# TDD bootstrap (SPI-1422): _spawn_cost starts wrong (0) so the cost test fails
# until _load_spawn_cost() is implemented; spawn_unit() is a no-op stub.
var _spawn_cost: int = 0


func _init() -> void:
	unit_type = "mother"


func is_auto_targetable() -> bool:
	return false


func spawn_unit() -> UnitBase:
	return null
```

- [ ] **Step 2: Write the failing tests**

Create `tests/unit/test_mother_spawn_drone.gd` with the full content below. `_expected_spawn_cost()` reads the cost from data so no test hardcodes `25`. Spawned Drones are added to the Mother's parent (the test node) but are not tracked by `add_child_autofree`, so each successful spawn is freed with `autofree(drone)`.

```gdscript
extends GutTest
## Unit tests for Mother drone spawning (SPI-1422): spawn_unit() charges biomass
## via ResourceManager, places a Level 1 Drone clear of the Mother on its team,
## announces via EventBus.unit_spawned, and returns the Drone (or null when the
## team cannot afford it).

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


func _expected_spawn_cost() -> int:
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return int(json.data["spawn_costs"]["drone"]["biomass"])


func test_spawn_cost_loaded_from_data() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	assert_eq(
		mother._spawn_cost, _expected_spawn_cost(), "cost should load from upgrade_costs.json"
	)


func test_successful_spawn_deducts_cost() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var before := ResourceManager.get_resources(1)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_eq(
		ResourceManager.get_resources(1),
		before - _expected_spawn_cost(),
		"biomass should drop by the spawn cost"
	)


func test_successful_spawn_returns_level1_drone_on_team() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_not_null(drone, "spawn should return the new Drone")
	assert_eq(drone.unit_type, "drone", "spawned unit should be a Drone")
	assert_eq(drone.team_id, 1, "Drone should be on the Mother's team")


func test_spawn_emits_unit_spawned() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	watch_signals(EventBus)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_signal_emitted(EventBus, "unit_spawned", "spawn should announce via EventBus")


func test_spawned_drone_clear_of_mother_and_controllable() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_gte(
		drone.position.distance_to(mother.position),
		48.0,
		"Drone must not overlap the Mother's body"
	)
	assert_true(drone.is_in_group("units"), "Drone should join the units group (controllable)")
	assert_eq(drone.get_parent(), mother.get_parent(), "Drone should be a sibling of the Mother")


func test_insufficient_biomass_no_spawn() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	# team 1 has 0 biomass (reset in before_each), below the spawn cost
	watch_signals(EventBus)
	var units_before := get_tree().get_nodes_in_group("units").size()
	var drone := mother.spawn_unit()
	assert_null(drone, "spawn should fail and return null")
	assert_eq(ResourceManager.get_resources(1), 0, "no biomass should be deducted")
	assert_eq(
		get_tree().get_nodes_in_group("units").size(),
		units_before,
		"no Drone should be created"
	)
	assert_signal_not_emitted(EventBus, "unit_spawned", "no spawn signal on failure")


func test_repeated_spawns_fan_out() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 200)
	var first := mother.spawn_unit()
	autofree(first)
	var second := mother.spawn_unit()
	autofree(second)
	assert_not_null(first, "first spawn should succeed")
	assert_not_null(second, "second spawn should succeed")
	assert_ne(first.position, second.position, "successive spawns should not stack")
```

- [ ] **Step 3: Run the suite and confirm the new tests are collected and (mostly) fail**

Run:
```bash
godot --headless --import 2>/dev/null; godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/spi1422-red.txt; grep -c "test_mother_spawn_drone" /tmp/spi1422-red.txt
```
Expected: the run collects `test_mother_spawn_drone.gd` (grep count ≥ 1 — proves it parsed, not silently skipped). Against the stub, `test_spawn_cost_loaded_from_data` fails (`_spawn_cost` is 0, not the data value) and the four positive-path tests plus the ring test fail (stub returns `null`, so no Drone/deduction/signal). `test_insufficient_biomass_no_spawn` PASSES against the stub — it asserts the no-op behavior the stub happens to have; that is expected and fine. Confirm you see multiple failures in `test_mother_spawn_drone`, not a clean green.

- [ ] **Step 4: Implement the real spawn logic**

Replace the entire contents of `scripts/units/mother_unit.gd` with:

```gdscript
class_name MotherUnit extends UnitBase
## The Mother: a large, slow, high-HP command unit. It cannot harvest and cannot
## auto-attack — both fall out of the "mother" stats entry having no
## harvest_speed / attack_range (they default to 0, so harvest_at() no-ops and
## no attack Area2D is built). It is also never auto-targeted by enemies. It
## converts stored biomass into Level 1 Drones via spawn_unit() (SPI-1422).
## Rally points come in a later M4 story (SPI-1424).

const DroneScene := preload("res://scenes/units/drone.tscn")

## Distance from the Mother's center at which spawned Drones appear. 60 exceeds
## the Mother's body radius (32) plus a Drone's radius (16), so a spawned Drone
## never overlaps the Mother.
const SPAWN_RADIUS: float = 60.0
## Angular step between successive spawns so repeated Drones fan out around the
## Mother instead of stacking. Uses a plain counter (no randf) for lockstep safety.
const SPAWN_ANGLE_STEP: float = TAU / 8.0

## Biomass charged per Drone; loaded from data/upgrade_costs.json in _ready.
var _spawn_cost: int = 25
## Number of Drones spawned so far; drives the placement-ring angle.
var _spawn_count: int = 0


func _init() -> void:
	unit_type = "mother"


func _ready() -> void:
	super._ready()
	_load_spawn_cost()


func is_auto_targetable() -> bool:
	return false


## Convert _spawn_cost biomass into a new Level 1 Drone on this Mother's team,
## placed clear of the Mother's body, and announce it. Returns the new Drone, or
## null if the team cannot afford it (no biomass spent, nothing created).
func spawn_unit() -> UnitBase:
	if not ResourceManager.spend_resources(team_id, _spawn_cost):
		return null
	var drone := DroneScene.instantiate() as UnitBase
	drone.team_id = team_id
	var angle := _spawn_count * SPAWN_ANGLE_STEP
	drone.position = position + Vector2.from_angle(angle) * SPAWN_RADIUS
	_spawn_count += 1
	get_parent().add_child(drone)
	EventBus.unit_spawned.emit(drone)
	return drone


func _load_spawn_cost() -> void:
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	if not file:
		push_warning("MotherUnit: Could not open upgrade_costs.json")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning(
			"MotherUnit: Failed to parse upgrade_costs.json: %s" % json.get_error_message()
		)
		return
	var data: Dictionary = json.data
	var spawn_costs: Dictionary = data.get("spawn_costs", {})
	var drone_cost: Dictionary = spawn_costs.get("drone", {})
	_spawn_cost = int(drone_cost.get("biomass", _spawn_cost))
```

- [ ] **Step 5: Add the real-scene integration test**

Append to `tests/unit/test_mother_spawn.gd`. First add a `before_each` that resets biomass (the file currently has only `before_all`), then the new test. Insert this `before_each` immediately after the existing `before_all()` function:

```gdscript
func before_each() -> void:
	ResourceManager.reset()
```

Then append this test at the end of the file:

```gdscript
func test_mother_spawns_drone_in_scene() -> void:
	var main := _main_scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var mother: MotherUnit = null
	for node in get_tree().get_nodes_in_group("units"):
		if node is MotherUnit and node.team_id == 1:
			mother = node
			break
	assert_not_null(mother, "player Mother should exist")
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	assert_not_null(drone, "spawn_unit should return a Drone in the real scene")
	assert_eq(drone.team_id, 1, "spawned Drone should be on the player team")
	assert_eq(
		drone.get_parent(), mother.get_parent(), "Drone should be a sibling of the Mother in the scene"
	)
```

The spawned Drone is a child of `main`, which is freed by `add_child_autofree(main)` — no separate cleanup needed.

- [ ] **Step 6: Run the suite and confirm all green**

Run:
```bash
godot --headless --import 2>/dev/null; godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/spi1422-green.txt; grep -E "Tests|Passing|Failing|Errors" /tmp/spi1422-green.txt | tail -5
```
Expected: all tests pass, 0 failures, 0 errors. Confirm the Tests count rose vs. the pre-task baseline (7 new unit tests + 1 new integration test). Confirm `grep -c "test_mother_spawn_drone" /tmp/spi1422-green.txt` ≥ 1 (file still collected).

- [ ] **Step 7: Format, lint, and commit**

Run:
```bash
gdformat scripts/units/mother_unit.gd tests/unit/test_mother_spawn_drone.gd tests/unit/test_mother_spawn.gd
gdlint scripts/units/mother_unit.gd
```
Expected: gdformat reports reformatted/unchanged with no error; gdlint prints `Success: no problems found`. If gdformat rewrites anything (e.g. collapses a multi-line call), re-run the suite (Step 6) to confirm still green.

```bash
git add scripts/units/mother_unit.gd tests/unit/test_mother_spawn_drone.gd tests/unit/test_mother_spawn.gd tests/unit/test_mother_spawn_drone.gd.uid
git commit -m "feat: spawn Drones from a Mother, paid in biomass (SPI-1422)

MotherUnit.spawn_unit() charges the team's biomass via ResourceManager,
instantiates a Level 1 Drone on a deterministic ring clear of the Mother's
body, and announces it via EventBus.unit_spawned. Cost is read from
data/upgrade_costs.json. Returns null (no charge) when unaffordable.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
(The `.uid` file is generated by Godot on import; include it if present. If `git add` of the `.uid` errors because it does not exist, drop it from the command.)

---

### Task 2: Harness debug spawn key

**Files:**
- Modify: `scripts/main.gd` (add `_player_mother` member, capture it in `_spawn_test_units()`, add `KEY_B` handler in `_unhandled_input`)

**Interfaces:**
- Consumes: `MotherUnit.spawn_unit()` from Task 1; existing `MotherScene` preload and `_spawn_test_units()` structure in `main.gd`.
- Produces: nothing consumed by later tasks.

This task is a temporary developer convenience with no automated test: the `KEY_B` binding is a thin shortcut over the already-fully-tested `spawn_unit()`, and simulating input dispatch for a throwaway hook is not worth the brittleness. It is verified manually and by the final whole-branch review. It exists so the PRD M4 testable outcome ("spawn units from Mother") can be exercised by hand before the SPI-1423 spawn button lands.

- [ ] **Step 1: Add the `_player_mother` member**

In `scripts/main.gd`, add this among the regular `var` declarations (after `_last_recall_time` on line 19, before the `@onready` block — gdlint requires plain vars before `@onready` vars):

```gdscript
var _player_mother: MotherUnit = null
```

- [ ] **Step 2: Capture the Mother when the harness creates it**

In `_spawn_test_units()`, set `_player_mother` right after the Mother is added. Change the tail of the function from:

```gdscript
	var mother := MotherScene.instantiate()
	mother.team_id = 1
	mother.position = Vector2(760, 400)
	mother.modulate = Color(0.6, 1.0, 0.6)
	add_child(mother)
	print("Spawned player Mother")
```
to:
```gdscript
	var mother := MotherScene.instantiate()
	mother.team_id = 1
	mother.position = Vector2(760, 400)
	mother.modulate = Color(0.6, 1.0, 0.6)
	add_child(mother)
	_player_mother = mother
	print("Spawned player Mother")
```

- [ ] **Step 3: Add the `KEY_B` debug spawn handler**

In `_unhandled_input`, extend the existing key branch (which handles the 1–5 control-group keys). Change:

```gdscript
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_5:
			var group_index: int = key - KEY_1
			if event.ctrl_pressed:
				SelectionManager.assign_group(group_index)
			else:
				_recall_group(group_index)
```
to:
```gdscript
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_5:
			var group_index: int = key - KEY_1
			if event.ctrl_pressed:
				SelectionManager.assign_group(group_index)
			else:
				_recall_group(group_index)
		elif key == KEY_B:
			# TEMP (SPI-1422): debug spawn from the player Mother; replaced by
			# the spawn button in SPI-1423.
			if is_instance_valid(_player_mother):
				_player_mother.spawn_unit()
```

- [ ] **Step 4: Run the full suite (regression) and format/lint**

Run:
```bash
godot --headless --import 2>/dev/null; godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/spi1422-task2.txt; grep -E "Tests|Passing|Failing|Errors" /tmp/spi1422-task2.txt | tail -5
gdformat scripts/main.gd
gdlint scripts/main.gd
```
Expected: suite still all green (0 failures/errors — `main.gd` changes don't affect existing tests, and the SPI-1421 `test_mother_spawn.gd` scene test still passes); gdformat clean; gdlint `Success: no problems found`.

- [ ] **Step 5: Manual verification (optional but recommended)**

Run the game (`godot --path . scenes/main/main.tscn`). Right-click a biomass node with a player Drone to gather at least the Drone spawn cost (25) of biomass, then press **B**. A new Drone should appear on the ring around the player Mother, on the player team, and be immediately selectable. (With 0 biomass, pressing B does nothing — that is the insufficient-biomass path.)

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: debug key (B) to spawn from the player Mother (SPI-1422)

Temporary harness hook for manual playtesting of Mother spawning, to be
superseded by the spawn button in SPI-1423.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Notes for the executor

- After the last task, dispatch the final whole-branch code review, then use superpowers:finishing-a-development-branch (open PR, review, fix loop).
- The CI runs `gdlint scripts/` only (not `tests/`), but format the test files anyway for consistency.
- If any `godot --headless --import` step prints import chatter to stderr, that is normal; the `2>/dev/null` suppresses it. Do not treat import output as a failure.
