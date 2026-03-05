# SPI-1372: Control Groups — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add control groups (Ctrl+1-5 to assign, 1-5 to recall, double-tap to center camera) so players can quickly command groups of units.

**Architecture:** Extend `SelectionManager` autoload with a 5-slot `_control_groups` array. `assign_group(n)` snapshots the current selection, `recall_group(n)` restores it. `remove_unit()` cleans dead units from groups. `main.gd` handles raw key events for Ctrl+N / N and double-tap detection.

**Tech Stack:** GDScript (Godot 4.6), GUT test framework, gdtoolkit (gdformat/gdlint)

**Design Doc:** `docs/plans/2026-02-25-spi-1372-control-groups-design.md`

---

### Task 1: Add assign_group() and recall_group() with tests

**Files:**
- Modify: `scripts/autoload/selection_manager.gd`
- Create: `tests/unit/test_control_groups.gd`

**Step 1: Create test file with first failing test**

Create `tests/unit/test_control_groups.gd`:

```gdscript
extends GutTest
## Tests for control group behavior (SPI-1372).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


func before_each() -> void:
	SelectionManager.deselect_all()
	SelectionManager.clear_all_groups()


func test_assign_and_recall_group() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(100, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a, unit_b] as Array[UnitBase])
	SelectionManager.assign_group(0)
	# Deselect, then recall
	SelectionManager.deselect_all()
	assert_eq(SelectionManager.get_selected_units().size(), 0, "should be deselected")
	SelectionManager.recall_group(0)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 2, "recall should restore 2 units")
	assert_has(selected, unit_a, "should contain unit_a")
	assert_has(selected, unit_b, "should contain unit_b")


func test_assign_replaces_previous_group() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(100, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a] as Array[UnitBase])
	SelectionManager.assign_group(0)
	# Reassign with different unit
	SelectionManager.select_units([unit_b] as Array[UnitBase])
	SelectionManager.assign_group(0)
	SelectionManager.deselect_all()
	SelectionManager.recall_group(0)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 1, "group should have 1 unit after reassign")
	assert_eq(selected[0], unit_b, "should be unit_b after reassign")


func test_recall_empty_group_does_nothing() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a] as Array[UnitBase])
	# Recall an unassigned group
	SelectionManager.recall_group(3)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 0, "recall empty group should deselect all")
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_control_groups.gd`

Expected: FAIL — `assign_group`, `recall_group`, `clear_all_groups` methods do not exist.

**Step 3: Implement in selection_manager.gd**

Add after `var _selected_units`:

```gdscript
const GROUP_COUNT: int = 5
var _control_groups: Array[Array] = [[], [], [], [], []]
```

Add after `remove_unit()`:

```gdscript
func assign_group(index: int) -> void:
	if index < 0 or index >= GROUP_COUNT:
		return
	_control_groups[index] = _selected_units.duplicate()


func recall_group(index: int) -> void:
	if index < 0 or index >= GROUP_COUNT:
		return
	var valid_units: Array[UnitBase] = []
	for unit in _control_groups[index]:
		if is_instance_valid(unit) and not unit._is_dead:
			valid_units.append(unit)
	_control_groups[index].assign(valid_units)
	select_units(valid_units)


func clear_all_groups() -> void:
	for i in range(GROUP_COUNT):
		_control_groups[i] = []
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_control_groups.gd`

Expected: 3 tests PASS.

**Step 5: Run all tests to verify no regressions**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS.

**Step 6: Format and lint**

Run: `gdformat scripts/autoload/selection_manager.gd tests/unit/test_control_groups.gd && gdlint scripts/autoload/selection_manager.gd`

**Step 7: Commit**

```bash
git add scripts/autoload/selection_manager.gd tests/unit/test_control_groups.gd
git commit -m "feat: add control group assign/recall to SelectionManager (SPI-1372)"
```

---

### Task 2: Death cleanup and multi-group membership tests

**Files:**
- Modify: `scripts/autoload/selection_manager.gd`
- Modify: `tests/unit/test_control_groups.gd`

**Step 1: Add failing test for death cleanup**

Add to `test_control_groups.gd`:

```gdscript
func test_dead_unit_removed_from_group() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(100, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a, unit_b] as Array[UnitBase])
	SelectionManager.assign_group(0)
	# Kill unit_a
	unit_a.take_damage(unit_a.max_health)
	# Recall group
	SelectionManager.recall_group(0)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 1, "dead unit should be removed from group")
	assert_eq(selected[0], unit_b, "surviving unit should remain")
```

**Step 2: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_control_groups.gd`

Expected: PASS — `recall_group` already filters dead/invalid units. However, we should also proactively clean groups in `remove_unit()` for consistency. If it passes, good — the filtering in `recall_group` handles it.

**Step 3: Update `remove_unit()` for proactive cleanup**

Replace `remove_unit()` in `selection_manager.gd`:

```gdscript
func remove_unit(unit: UnitBase) -> void:
	if unit in _selected_units:
		_selected_units.erase(unit)
		selection_changed.emit(_selected_units)
	for group in _control_groups:
		group.erase(unit)
```

**Step 4: Add multi-group membership test**

Add to `test_control_groups.gd`:

```gdscript
func test_unit_in_multiple_groups() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(100, 0))
	await get_tree().process_frame
	# Assign unit_a to group 0
	SelectionManager.select_units([unit_a] as Array[UnitBase])
	SelectionManager.assign_group(0)
	# Assign unit_a + unit_b to group 1
	SelectionManager.select_units([unit_a, unit_b] as Array[UnitBase])
	SelectionManager.assign_group(1)
	# Recall group 0
	SelectionManager.recall_group(0)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 1, "group 0 should have 1 unit")
	assert_eq(selected[0], unit_a, "group 0 should have unit_a")
	# Recall group 1
	SelectionManager.recall_group(1)
	selected = SelectionManager.get_selected_units()
	assert_eq(selected.size(), 2, "group 1 should have 2 units")
```

**Step 5: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS.

**Step 6: Format and lint**

Run: `gdformat scripts/autoload/selection_manager.gd tests/unit/test_control_groups.gd && gdlint scripts/autoload/selection_manager.gd`

**Step 7: Commit**

```bash
git add scripts/autoload/selection_manager.gd tests/unit/test_control_groups.gd
git commit -m "feat: add death cleanup and multi-group tests (SPI-1372)"
```

---

### Task 3: Add get_group_center() with test

**Files:**
- Modify: `scripts/autoload/selection_manager.gd`
- Modify: `tests/unit/test_control_groups.gd`

**Step 1: Write failing test**

Add to `test_control_groups.gd`:

```gdscript
func test_group_center_calculation() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(200, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a, unit_b] as Array[UnitBase])
	SelectionManager.assign_group(0)
	var center := SelectionManager.get_group_center(0)
	assert_almost_eq(center.x, 100.0, 1.0, "center X should be average of 0 and 200")
	assert_almost_eq(center.y, 0.0, 1.0, "center Y should be 0")


func test_group_center_empty_returns_zero() -> void:
	var center := SelectionManager.get_group_center(2)
	assert_eq(center, Vector2.ZERO, "empty group center should be Vector2.ZERO")
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_control_groups.gd`

Expected: FAIL — `get_group_center` method does not exist.

**Step 3: Implement get_group_center()**

Add to `selection_manager.gd` after `clear_all_groups()`:

```gdscript
func get_group_center(index: int) -> Vector2:
	if index < 0 or index >= GROUP_COUNT:
		return Vector2.ZERO
	var group: Array = _control_groups[index]
	if group.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	var count := 0
	for unit in group:
		if is_instance_valid(unit):
			center += unit.global_position
			count += 1
	if count == 0:
		return Vector2.ZERO
	return center / count
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_control_groups.gd`

Expected: All tests PASS.

**Step 5: Format and lint**

Run: `gdformat scripts/autoload/selection_manager.gd tests/unit/test_control_groups.gd && gdlint scripts/autoload/selection_manager.gd`

**Step 6: Commit**

```bash
git add scripts/autoload/selection_manager.gd tests/unit/test_control_groups.gd
git commit -m "feat: add get_group_center() for camera snap (SPI-1372)"
```

---

### Task 4: Wire Ctrl+N assign and N recall input in main.gd

**Files:**
- Modify: `scripts/main.gd`

**Step 1: Add key handling to `_unhandled_input()`**

Add a new `elif` branch after the `attack_move` handler and before the `command` handler:

```gdscript
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event.keycode
		if key >= KEY_1 and key <= KEY_5:
			var group_index := key - KEY_1
			if event.ctrl_pressed:
				SelectionManager.assign_group(group_index)
			else:
				SelectionManager.recall_group(group_index)
```

**Step 2: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS.

**Step 3: Format and lint**

Run: `gdformat scripts/main.gd && gdlint scripts/main.gd`

**Step 4: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: wire Ctrl+N assign and N recall input (SPI-1372)"
```

---

### Task 5: Add double-tap camera snap

**Files:**
- Modify: `scripts/main.gd`

**Step 1: Add double-tap tracking variables**

Add after `var _attack_move_pending`:

```gdscript
const DOUBLE_TAP_THRESHOLD: float = 0.3
var _last_recall_group: int = -1
var _last_recall_time: float = 0.0
```

**Step 2: Extract recall logic to `_recall_group()` method**

Replace the inline `SelectionManager.recall_group(group_index)` call in the key handler with:

```gdscript
			else:
				_recall_group(group_index)
```

Add new method after `_issue_attack_move()`:

```gdscript
func _recall_group(index: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if index == _last_recall_group and (now - _last_recall_time) < DOUBLE_TAP_THRESHOLD:
		var center := SelectionManager.get_group_center(index)
		if center != Vector2.ZERO:
			_camera.global_position = center
	_last_recall_group = index
	_last_recall_time = now
	SelectionManager.recall_group(index)
```

**Step 3: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS.

**Step 4: Format and lint**

Run: `gdformat scripts/main.gd && gdlint scripts/main.gd`

**Step 5: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: add double-tap camera snap for control groups (SPI-1372)"
```

---

### Task 6: Final verification and cleanup

**Files:**
- All modified files

**Step 1: Run full test suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS.

**Step 2: Format check all touched files**

Run: `gdformat --check scripts/autoload/selection_manager.gd scripts/main.gd tests/unit/test_control_groups.gd`

Expected: All files formatted correctly.

**Step 3: Lint all touched files**

Run: `gdlint scripts/autoload/selection_manager.gd scripts/main.gd`

Expected: No problems found.

**Step 4: Manual smoke test**

Run: `godot --path . scenes/main/main.tscn`

Verify:
1. Select units, Ctrl+1 to assign group — no visible change (assignment is silent)
2. Click elsewhere to deselect, press 1 — units are reselected with highlights
3. Ctrl+2 to assign a different group, press 2 to recall — correct units selected
4. Double-tap 1 — camera centers on group 1's position
5. Kill a unit in a group, recall group — dead unit is not included
6. Ctrl+1 with new selection — overwrites previous group 1
