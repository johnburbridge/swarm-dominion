# Mother Unit — Scene, Stats & Slow Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a selectable, slowly-mobile, high-HP Mother unit that cannot harvest, cannot auto-attack, and is never auto-targeted by enemies.

**Architecture:** New `MotherUnit extends UnitBase` subclass + `mother.tscn` scene reusing drone art at 2× scale. Movement/health/selection/stat-loading are inherited. The "no harvest" and "no auto-attack" behaviors fall out of the `mother` stats entry having no `harvest_speed`/`attack_range` (both default to 0). One shared `UnitBase` change adds an `is_auto_targetable()` predicate and a guard so enemies never enlist a Mother as a target. A player Mother is added to the test-scene spawn harness.

**Tech Stack:** Godot 4.7.stable, GDScript, GUT 9.5.0. Lint: gdformat/gdlint.

## Global Constraints

- **GDScript conventions:** `class_name X extends Y` on line 1; `UPPER_SNAKE_CASE` consts; typed `var`s with hints; leading `_` for private; type hints on all params and returns.
- **Declaration order (gdlint `class-definitions-order`):** signals → enums → constants → `@export` vars → regular `var` → `@onready` var → methods. Regular `var` must precede `@onready var`.
- **Determinism (PRD lockstep goal):** no `randf`/`randi` or wall-clock in unit logic.
- **Data-driven stats:** unit stats come from `data/unit_stats.json`, keyed by `unit_type`. The `mother` entry already exists (`health: 500`, `move_speed: 50`, `vision_range: 250`, `base_supply: 10`, `spawn_time: 3.0`) — do NOT modify it.
- **New `class_name` files require an import pass:** after creating `mother_unit.gd`, run `godot --headless --import` before any script that references `MotherUnit` (or loads `mother.tscn`) will parse. Confirm test counts rise — GUT silently skips parse-errored test files and still reports "All tests passed".
- **Run the full suite** (`.gutconfig.json` sets `dirs`, so `-gtest=` is ignored): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Grep output for the new test file name and confirm Scripts/Tests counts increased.
- **Existing player team id is `1`** (`main.gd` `PLAYER_TEAM_ID`); drones spawn on teams 1 (player) and 2 (enemy).
- **Tests read "private" members freely** (`_state`, `_enemies_in_range`, `_attack_area`, `_selection_circle`) — this matches the established test style (`test_command_dispatch.gd`, `test_harvest_indicator.gd`). The `UnitState` enum is referenced as `UnitBase.UnitState.<NAME>`.

---

### Task 1: `MotherUnit` subclass, `mother.tscn`, and `is_auto_targetable()` predicate

Delivers the Mother as a unit: correct stats, identity, the behavioral exclusions that come for free from data, inherited movement/selection, and the `is_auto_targetable()` predicate on `UnitBase` (default `true`) with the Mother's `false` override. The guard that *consumes* the predicate is Task 2.

**Files:**
- Create: `scripts/units/mother_unit.gd`
- Create: `scenes/units/mother.tscn`
- Modify: `scripts/units/unit_base.gd` (add `is_auto_targetable()` after `is_harvesting()`, ~line 143)
- Test: `tests/unit/test_mother_unit.gd`

**Interfaces:**
- Consumes: `UnitBase` (movement, health, selection, `_load_stats`, `harvest_at`, `is_harvesting`, `UnitState` enum, `_state`, `_selection_circle`, `_attack_area`).
- Produces:
  - `UnitBase.is_auto_targetable() -> bool` (default `true`) — consumed by Task 2's guard.
  - `class_name MotherUnit extends UnitBase`, overriding `is_auto_targetable() -> bool` (`false`) and setting `unit_type = "mother"` in `_init()`.
  - `res://scenes/units/mother.tscn` — root `Mother` (`CharacterBody2D`, `mother_unit.gd`), `AnimatedSprite2D` (drone frames, `scale (2,2)`), `CollisionShape2D` (radius 32), `HealthBar`. No `HarvestIndicator`, no `AttackRange`.

- [ ] **Step 1: Bootstrap so the tests can reference `MotherUnit` and load the scene**

The test file types `as MotherUnit` and `load()`s `mother.tscn`, so both the class and the scene must exist (and be imported) before the tests can even parse. Create them minimally now; the Mother's real behavior is implemented in Step 3.

Create `scripts/units/mother_unit.gd` as a stub:

```gdscript
class_name MotherUnit extends UnitBase
## The Mother: a large, slow, high-HP command unit (SPI-1421). Stats/exclusion
## behavior is added in this task; spawning (SPI-1422) and rally (SPI-1424) later.
```

Add the `is_auto_targetable()` seam to `scripts/units/unit_base.gd`, immediately after the `is_harvesting()` method (after line 143). Default `true` is a no-op for every existing unit; the `MotherUnit` override (Step 3) and the Task 2 guard give it teeth. It exists now so the drone/Mother targetability assertions can run:

```gdscript
# Whether enemies may pick this unit as an automatic attack target. Mothers
# override this to false; they must be targeted manually (future work). The
# guard that consumes this lives in _on_body_entered_attack_range (Task 2).
func is_auto_targetable() -> bool:
	return true
```

Create `scenes/units/mother.tscn` (mirrors `drone.tscn`, minus the HarvestIndicator, with a 2× sprite and a radius-32 collider). Note it does **not** set `unit_type`; the subclass sets it in `_init()`, which keeps the source of truth in one place and makes the Step-2 failures meaningful (the stub loads drone stats until Step 3):

```
[gd_scene load_steps=5 format=3 uid="uid://mother_scene"]

[ext_resource type="Script" path="res://scripts/units/mother_unit.gd" id="1_script"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/units/drone_frames.tres" id="2_frames"]
[ext_resource type="PackedScene" uid="uid://health_bar_scene" path="res://scenes/ui/health_bar.tscn" id="3_health_bar"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 32.0

[node name="Mother" type="CharacterBody2D"]
script = ExtResource("1_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
scale = Vector2(2, 2)
sprite_frames = ExtResource("2_frames")
animation = &"idle"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")

[node name="HealthBar" parent="." instance=ExtResource("3_health_bar")]
```

Run: `godot --headless --import`
Expected: completes without fatal errors; `scripts/units/mother_unit.gd.uid` is generated.

- [ ] **Step 2: Write the tests and run them to verify they fail**

Create `tests/unit/test_mother_unit.gd`:

```gdscript
extends GutTest
## Tests for the Mother unit (SPI-1421): a large, slow, high-HP command unit
## that cannot harvest, cannot auto-attack, is never auto-targeted, but is
## selectable and movable like any other unit.

var _mother_scene: PackedScene
var _drone_scene: PackedScene
var _node_scene: PackedScene


func before_all() -> void:
	_mother_scene = load("res://scenes/units/mother.tscn")
	_drone_scene = load("res://scenes/units/drone.tscn")
	_node_scene = load("res://scenes/resources/biomass_node.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _create_mother(tid: int, pos: Vector2) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = pos
	add_child_autofree(mother)
	return mother


func _create_drone(tid: int, pos: Vector2) -> UnitBase:
	var drone := _drone_scene.instantiate() as UnitBase
	drone.team_id = tid
	drone.position = pos
	add_child_autofree(drone)
	return drone


func _create_node(pos: Vector2) -> BiomassNode:
	var node := _node_scene.instantiate() as BiomassNode
	node.position = pos
	add_child_autofree(node)
	return node


# --- Stats & identity ---


func test_mother_loads_high_hp_stats() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.max_health, 500, "Mother max_health should load 500 from stats")
	assert_eq(mother.current_health, 500, "Mother should start at full health")


func test_mother_loads_slow_move_speed() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.move_speed, 50.0, "Mother move_speed should load 50 from stats")


func test_mother_unit_type() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.unit_type, "mother", "Mother unit_type should be 'mother'")


func test_mother_is_not_auto_targetable() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_false(mother.is_auto_targetable(), "Mother should not be auto-targetable")


func test_drone_is_auto_targetable_by_default() -> void:
	var drone := _create_drone(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_true(drone.is_auto_targetable(), "Drone should be auto-targetable by default")


# --- Behavioral exclusions ---


func test_mother_cannot_harvest() -> void:
	var node := _create_node(Vector2.ZERO)
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	mother.harvest_at(node)
	assert_false(mother.is_harvesting(), "Mother must not enter HARVESTING")
	assert_eq(mother._state, UnitBase.UnitState.IDLE, "Mother should stay IDLE after harvest_at")


func test_mother_has_no_attack_area() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.attack_range, 0.0, "Mother attack_range should be 0 (no attack keys in stats)")
	assert_null(mother._attack_area, "Mother should build no attack Area2D")
	assert_null(mother.get_node_or_null("AttackRange"), "Mother should have no AttackRange child")


# --- Movement & selection (inherited, verified for the Mother) ---


func test_mother_moves_when_commanded() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	mother.move_to(Vector2(500, 0))
	assert_eq(mother._state, UnitBase.UnitState.MOVING, "Mother should enter MOVING on move_to")
	for _i in range(10):
		await get_tree().physics_frame
	assert_gt(mother.position.x, 0.0, "Mother should advance toward its move target")


func test_mother_selection_toggles_circle() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	mother.set_selected(true)
	assert_true(mother._selection_circle.visible, "selection circle should show when selected")
	mother.set_selected(false)
	assert_false(mother._selection_circle.visible, "selection circle should hide when deselected")
```

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: `test_mother_unit.gd` appears in output (Scripts count +1, Tests count +9 vs. the prior run — verify, since a parse-errored file is silently skipped and still reports green). Because the stub still loads drone stats and doesn't override targetability, these FAIL:
- `test_mother_loads_high_hp_stats` — FAIL (`max_health` 50, not 500)
- `test_mother_loads_slow_move_speed` — FAIL (150, not 50)
- `test_mother_unit_type` — FAIL ("drone")
- `test_mother_is_not_auto_targetable` — FAIL (returns true)
- `test_mother_cannot_harvest` — FAIL (drone `harvest_speed` 5 → enters HARVESTING)
- `test_mother_has_no_attack_area` — FAIL (drone `attack_range` 80 → area built)

and these PASS already: `test_drone_is_auto_targetable_by_default` (seam default true), `test_mother_moves_when_commanded`, `test_mother_selection_toggles_circle` (inherited). If a should-fail test passes, the stub is accidentally correct — investigate before Step 3.

- [ ] **Step 3: Implement the Mother behavior**

Replace `scripts/units/mother_unit.gd` with the full implementation:

```gdscript
class_name MotherUnit extends UnitBase
## The Mother: a large, slow, high-HP command unit. It cannot harvest and cannot
## auto-attack — both fall out of the "mother" stats entry having no
## harvest_speed / attack_range (they default to 0, so harvest_at() no-ops and
## no attack Area2D is built). It is also never auto-targeted by enemies. Later
## M4 stories add spawning (SPI-1422) and rally points (SPI-1424) here.


func _init() -> void:
	unit_type = "mother"


func is_auto_targetable() -> bool:
	return false
```

`_init()` runs at construction, before `UnitBase._ready()` calls `_load_stats()`, so the `mother` stats are loaded. The scene stores no `unit_type`, so nothing overrides `_init`'s value.

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all 9 `test_mother_unit.gd` tests PASS. Every pre-existing test remains green (the `is_auto_targetable()` seam defaults to `true`, a no-op for existing units).

- [ ] **Step 5: Format and lint**

Run: `gdformat scripts/units/mother_unit.gd scripts/units/unit_base.gd tests/unit/test_mother_unit.gd`
Run: `gdlint scripts/units/mother_unit.gd scripts/units/unit_base.gd`
Expected: no errors. (CI lints `scripts/` only; `gdlint` on the test file is optional and any `max-public-methods` warning is non-blocking and pre-existing across the suite.)

- [ ] **Step 6: Commit**

```bash
git add scripts/units/mother_unit.gd scripts/units/mother_unit.gd.uid scenes/units/mother.tscn scripts/units/unit_base.gd tests/unit/test_mother_unit.gd tests/unit/test_mother_unit.gd.uid
git commit -m "feat: add Mother unit scene, stats, and is_auto_targetable predicate (SPI-1421)"
```

---

### Task 2: Auto-target exclusion guard in `UnitBase`

Delivers the behavioral half of "never auto-targeted": enemies skip non-auto-targetable units when populating their target list, so a Mother is never enlisted (and therefore never acquired via `_try_acquire_target`).

**Files:**
- Modify: `scripts/units/unit_base.gd:378-380` (`_on_body_entered_attack_range`)
- Test: `tests/unit/test_mother_unit.gd` (append)

**Interfaces:**
- Consumes: `UnitBase.is_auto_targetable()` (Task 1), `MotherUnit` (Task 1), `_enemies_in_range`.
- Produces: no new public API — a guarded `_on_body_entered_attack_range`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_mother_unit.gd`:

```gdscript
# --- Auto-target exclusion (the shared-code guard) ---


func test_enemy_does_not_enlist_mother_as_target() -> void:
	var drone := _create_drone(1, Vector2.ZERO)
	var mother := _create_mother(2, Vector2(30, 0))
	await get_tree().process_frame
	drone._on_body_entered_attack_range(mother)
	assert_does_not_have(
		drone._enemies_in_range, mother, "an enemy Mother must never be enlisted as a target"
	)


func test_enemy_does_enlist_a_normal_enemy_drone() -> void:
	var drone := _create_drone(1, Vector2.ZERO)
	var enemy := _create_drone(2, Vector2(30, 0))
	await get_tree().process_frame
	drone._on_body_entered_attack_range(enemy)
	assert_has(
		drone._enemies_in_range, enemy, "a normal enemy drone must still be enlisted (guard is specific)"
	)
```

- [ ] **Step 2: Run tests to verify they fail (the right one)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: `test_enemy_does_not_enlist_mother_as_target` FAILS (the Mother is currently appended to `_enemies_in_range`, since no guard exists yet). `test_enemy_does_enlist_a_normal_enemy_drone` PASSES (baseline behavior). If the first test passes, the guard test is not exercising the gap — re-check.

- [ ] **Step 3: Add the guard**

In `scripts/units/unit_base.gd`, replace `_on_body_entered_attack_range` (lines 378-380):

```gdscript
func _on_body_entered_attack_range(body: Node2D) -> void:
	if (
		body is UnitBase
		and body != self
		and body.team_id != team_id
		and not body._is_dead
		and body.is_auto_targetable()
	):
		_enemies_in_range.append(body)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: both new tests PASS. All pre-existing tests (especially `test_unit_auto_attack.gd`) remain green — normal enemy units default `is_auto_targetable()` to `true`, so their enlistment is unchanged.

- [ ] **Step 5: Format, lint, and commit**

Run: `gdformat scripts/units/unit_base.gd tests/unit/test_mother_unit.gd`
Run: `gdlint scripts/units/unit_base.gd`
Expected: no errors.

```bash
git add scripts/units/unit_base.gd tests/unit/test_mother_unit.gd
git commit -m "feat: exclude non-auto-targetable units from enemy target acquisition (SPI-1421)"
```

---

### Task 3: Spawn a player Mother in the test scene

Delivers the "appears when the main scene loads" AC: one player-team Mother is instantiated in the spawn harness, visible and selectable.

**Files:**
- Modify: `scripts/main.gd` (`MotherScene` preload near line 5; spawn block at the end of `_spawn_test_units()`, ~line 243)
- Test: `tests/unit/test_mother_spawn.gd`

**Interfaces:**
- Consumes: `mother.tscn` (Task 1), `MotherUnit` (Task 1), the `"units"` group, `main.tscn`. `main.tscn` is fully instantiable in a GUT test — `test_command_dispatch.gd` already does `load("res://scenes/main/main.tscn").instantiate()` + `add_child_autofree`.
- Produces: exactly one `MotherUnit` on team 1 present in the running main scene.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_mother_spawn.gd`:

```gdscript
extends GutTest
## Integration test (SPI-1421): the main scene spawns exactly one player Mother,
## discoverable via the standard "units" group on the player team.

var _main_scene: PackedScene


func before_all() -> void:
	_main_scene = load("res://scenes/main/main.tscn")


func _count_player_mothers() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("units"):
		if node is MotherUnit and node.team_id == 1:
			count += 1
	return count


func test_main_scene_spawns_one_player_mother() -> void:
	var main := _main_scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_eq(_count_player_mothers(), 1, "main scene should spawn exactly one player Mother")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: `test_main_scene_spawns_one_player_mother` FAILS with count 0 (no Mother spawned yet). Confirm `test_mother_spawn.gd` shows up in the output (Scripts count +1).

- [ ] **Step 3: Add the `MotherScene` preload**

In `scripts/main.gd`, add after the `BiomassNodeScene` preload (line 6):

```gdscript
const MotherScene = preload("res://scenes/units/mother.tscn")
```

- [ ] **Step 4: Spawn the player Mother**

In `scripts/main.gd`, at the very end of `_spawn_test_units()` (after the enemy-drone loop and its `print`, ~line 243), add:

```gdscript
	var mother := MotherScene.instantiate()
	mother.team_id = 1
	mother.position = Vector2(760, 400)
	mother.modulate = Color(0.6, 1.0, 0.6)
	add_child(mother)
	print("Spawned player Mother")
```

The position sits above the player drone cluster (drones occupy ~y 480–600) so the Mother does not overlap them; the tint is a deeper green than the drones' `Color(0.7, 1.0, 0.7)` to distinguish it while keeping the team read.

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: `test_main_scene_spawns_one_player_mother` PASSES. Entire suite green.

- [ ] **Step 6: Format, lint, and commit**

Run: `gdformat scripts/main.gd tests/unit/test_mother_spawn.gd`
Run: `gdlint scripts/main.gd`
Expected: no errors.

```bash
git add scripts/main.gd tests/unit/test_mother_spawn.gd tests/unit/test_mother_spawn.gd.uid
git commit -m "feat: spawn a player Mother in the test scene (SPI-1421)"
```

---

## Self-Review

**Spec coverage:**
- AC "Scene and stats" → Task 1 (stats tests, scene, larger sprite).
- AC "Slow movement" → Task 1 `test_mother_moves_when_commanded`.
- AC "Cannot harvest" → Task 1 `test_mother_cannot_harvest`.
- AC "Not auto-targeted" → Task 1 predicate/override + Task 2 guard and its two tests.
- AC "Selection" → Task 1 `test_mother_selection_toggles_circle` (unit) + Task 3 integration (present in `"units"` group on the player team, selectable via the standard path).

**Placeholder scan:** none — every step has concrete code/commands and expected output.

**Type consistency:** `is_auto_targetable() -> bool` is named identically in `UnitBase`, the `MotherUnit` override, and the guard. `MotherUnit`, `mother.tscn`, `unit_type = "mother"`, radius `32.0`, `scale (2,2)`, team `1`, and tint `Color(0.6, 1.0, 0.6)` match the spec throughout. `UnitBase.UnitState.MOVING`/`IDLE` are referenced via the enum on the base class.

**Assertions used** (`assert_eq`, `assert_true`, `assert_false`, `assert_null`, `assert_gt`, `assert_has`, `assert_does_not_have`) are standard GUT — mirror `test_harvest_indicator.gd` / `test_command_dispatch.gd`.
