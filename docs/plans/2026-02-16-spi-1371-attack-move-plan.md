# SPI-1371: Attack-Move Command — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add attack-move (A + click) so units engage enemies while walking to a destination, then resume their path after each kill.

**Architecture:** Refactor `unit_base.gd` from implicit boolean state (`_is_moving`, `_is_dead`) to an explicit `UnitState` enum with 5 states: IDLE, MOVING, ATTACKING, ATTACK_MOVING, DEAD. Add `attack_move_to()` public method and `_process_attack_moving()` internal method. Wire A-click input in `main.gd`.

**Tech Stack:** GDScript (Godot 4.6), GUT test framework, gdtoolkit (gdformat/gdlint)

**Design Doc:** `docs/plans/2026-02-16-spi-1371-attack-move-design.md`

---

### Task 1: Refactor unit_base.gd to UnitState enum (pure refactor)

No behavior changes — all existing tests must pass unchanged afterward.

**Files:**
- Modify: `scripts/units/unit_base.gd`

**Step 1: Add UnitState enum, _state var, _has_attack_move_destination, and getter properties**

Add the enum after the signals block, replace `_is_dead` and `_is_moving` vars with getters, and add `_has_attack_move_destination`:

```gdscript
# After the signals (line 7), add:
enum UnitState { IDLE, MOVING, ATTACKING, ATTACK_MOVING, DEAD }

# Replace:
#   var _is_dead: bool = false
# With:
var _is_dead: bool:
	get:
		return _state == UnitState.DEAD

# Replace:
#   var _is_moving: bool = false  (currently at line 25 area)
# Remove _is_moving entirely — not referenced externally in tests
# Actually it IS referenced in tests (test_unit_health.gd:87, test_unit_auto_attack.gd:215,226)
# So add a getter:
var _is_moving: bool:
	get:
		return _state == UnitState.MOVING or _state == UnitState.ATTACK_MOVING

# Add new state variables (near line 22-28 area):
var _state: UnitState = UnitState.IDLE
var _has_attack_move_destination: bool = false
```

**Step 2: Update `move_to()` to use `_state`**

Replace the current implementation:

```gdscript
func move_to(target: Vector2) -> void:
	if _state == UnitState.DEAD:
		return
	if position.distance_to(target) <= ARRIVAL_THRESHOLD:
		return
	_target_position = target
	_state = UnitState.MOVING
	_attack_target = null
	_has_attack_move_destination = false
	attack_stopped.emit()
```

**Step 3: Update `_die()` to use `_state`**

Replace `_is_dead = true` and `_is_moving = false` with `_state = UnitState.DEAD`:

```gdscript
func _die() -> void:
	_state = UnitState.DEAD
	SelectionManager.remove_unit(self)
	velocity = Vector2.ZERO
	_attack_target = null
	_enemies_in_range.clear()
	# ... rest unchanged (attack_area disable, death anim, group removal, tween) ...
```

**Step 4: Update `_physics_process()` to use match statement**

```gdscript
func _physics_process(delta: float) -> void:
	match _state:
		UnitState.IDLE:
			_try_acquire_target()
		UnitState.MOVING:
			_process_movement()
		UnitState.ATTACKING:
			_process_attacking(delta)
		UnitState.ATTACK_MOVING:
			_process_attack_moving()
		UnitState.DEAD:
			pass
```

Note: `_process_attack_moving()` doesn't exist yet — add a stub:

```gdscript
func _process_attack_moving() -> void:
	_process_movement()
```

**Step 5: Update `_process_movement()` arrival to use `_state`**

Replace `_is_moving = false` on arrival:

```gdscript
func _process_movement() -> void:
	var distance := position.distance_to(_target_position)

	if distance <= ARRIVAL_THRESHOLD:
		_state = UnitState.IDLE
		_has_attack_move_destination = false
		velocity = Vector2.ZERO
		_update_animation()
		return

	var direction := (_target_position - position).normalized()
	velocity = direction * move_speed

	_update_animation(direction)

	move_and_slide()
```

**Step 6: Update `_try_acquire_target()` to set ATTACKING state**

When a target is acquired, set state:

```gdscript
func _try_acquire_target() -> void:
	var nearest: UnitBase = null
	var nearest_dist := INF
	for enemy in _enemies_in_range:
		if not _is_valid_target(enemy):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest != null:
		_attack_target = nearest
		_attack_cooldown = 0.0
		_state = UnitState.ATTACKING
		attack_started.emit(nearest)
```

**Step 7: Update `_process_attacking()` to transition correctly when target lost**

When the target becomes invalid:

```gdscript
func _process_attacking(delta: float) -> void:
	if not _is_valid_target(_attack_target):
		_attack_target = null
		attack_stopped.emit()
		if _has_attack_move_destination:
			_state = UnitState.ATTACK_MOVING
		else:
			_state = UnitState.IDLE
			_try_acquire_target()
		return

	# Face the target
	var dir_x := _attack_target.global_position.x - global_position.x
	if abs(dir_x) > 0.1:
		_sprite.flip_h = dir_x < 0

	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		_perform_attack()
		_attack_cooldown = _get_attack_interval()
```

**Step 8: Run all existing tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All existing tests pass (test_unit_health, test_unit_death, test_unit_auto_attack, test_unit_selection, test_selection_manager, test_drag_select). The `_is_dead` and `_is_moving` getter properties ensure backward compatibility.

**Step 9: Format and lint**

Run: `gdformat scripts/units/unit_base.gd && gdlint scripts/units/unit_base.gd`

Expected: No errors.

**Step 10: Commit**

```bash
git add scripts/units/unit_base.gd
git commit -m "refactor: replace boolean state with UnitState enum in unit_base (SPI-1371)"
```

---

### Task 2: Add attack_move_to() with test

**Files:**
- Modify: `scripts/units/unit_base.gd`
- Create: `tests/unit/test_attack_move.gd`

**Step 1: Write the test file scaffold and first failing test**

Create `tests/unit/test_attack_move.gd`:

```gdscript
extends GutTest
## Tests for attack-move behavior (SPI-1371).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


func test_attack_move_sets_state() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.attack_move_to(Vector2(500, 0))
	assert_eq(
		unit._state, UnitBase.UnitState.ATTACK_MOVING,
		"attack_move_to should set state to ATTACK_MOVING"
	)
	assert_true(unit._has_attack_move_destination, "should set _has_attack_move_destination")


func test_dead_unit_ignores_attack_move() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.take_damage(unit.max_health)
	unit.attack_move_to(Vector2(500, 0))
	assert_eq(
		unit._state, UnitBase.UnitState.DEAD,
		"dead unit should remain in DEAD state after attack_move_to"
	)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_attack_move.gd`

Expected: FAIL — `attack_move_to` method does not exist.

**Step 3: Implement `attack_move_to()` in `unit_base.gd`**

Add after `move_to()`:

```gdscript
func attack_move_to(target: Vector2) -> void:
	if _state == UnitState.DEAD:
		return
	if position.distance_to(target) <= ARRIVAL_THRESHOLD:
		return
	_target_position = target
	_state = UnitState.ATTACK_MOVING
	_attack_target = null
	_has_attack_move_destination = true
	attack_stopped.emit()
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_attack_move.gd`

Expected: 2 tests PASS.

**Step 5: Format and lint**

Run: `gdformat scripts/units/unit_base.gd tests/unit/test_attack_move.gd && gdlint scripts/units/unit_base.gd tests/unit/test_attack_move.gd`

**Step 6: Commit**

```bash
git add scripts/units/unit_base.gd tests/unit/test_attack_move.gd
git commit -m "feat: add attack_move_to() method with tests (SPI-1371)"
```

---

### Task 3: Attack-move engages enemies during movement

**Files:**
- Modify: `scripts/units/unit_base.gd` (update `_process_attack_moving()` stub)
- Modify: `tests/unit/test_attack_move.gd`

**Step 1: Write failing test**

Add to `test_attack_move.gd`:

```gdscript
func test_attack_move_engages_enemy_in_range() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	attacker.attack_move_to(Vector2(500, 0))
	# Place enemy within attack range along the path
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	# Allow physics to detect the enemy and attack-move to engage
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		attacker._state, UnitBase.UnitState.ATTACKING,
		"attack-moving unit should transition to ATTACKING when enemy in range"
	)
	assert_eq(attacker._attack_target, enemy, "should target the enemy")
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_attack_move.gd::test_attack_move_engages_enemy_in_range`

Expected: FAIL — the stub `_process_attack_moving()` only calls `_process_movement()` and does not scan for targets.

**Step 3: Update `_process_attack_moving()` to scan for targets**

Replace the stub in `unit_base.gd`:

```gdscript
func _process_attack_moving() -> void:
	if _attack_target == null:
		_try_acquire_target()
	if _attack_target != null:
		_state = UnitState.ATTACKING
		return
	_process_movement()
```

Note: `_try_acquire_target()` already sets `_state = UnitState.ATTACKING` (from Task 1 Step 6), so the `if _attack_target != null` check handles the transition. However, we explicitly set state here as a safety net since `_try_acquire_target` transitions from IDLE. Actually — we need `_try_acquire_target` to NOT set state itself, since it's called from multiple contexts. Let me reconsider.

**Important:** Revert the `_state = UnitState.ATTACKING` line added to `_try_acquire_target()` in Task 1 Step 6. Instead, have each caller manage the state transition:

Update `_try_acquire_target()` to NOT set state:

```gdscript
func _try_acquire_target() -> void:
	var nearest: UnitBase = null
	var nearest_dist := INF
	for enemy in _enemies_in_range:
		if not _is_valid_target(enemy):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest != null:
		_attack_target = nearest
		_attack_cooldown = 0.0
		attack_started.emit(nearest)
```

Update `_physics_process` IDLE branch to set state:

```gdscript
UnitState.IDLE:
	_try_acquire_target()
	if _attack_target != null:
		_state = UnitState.ATTACKING
```

And `_process_attack_moving()` manages its own transition (already shown above).

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_attack_move.gd`

Expected: All 3 tests PASS.

**Step 5: Run all tests to verify no regressions**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS.

**Step 6: Commit**

```bash
git add scripts/units/unit_base.gd tests/unit/test_attack_move.gd
git commit -m "feat: attack-move engages enemies during movement (SPI-1371)"
```

---

### Task 4: Resume movement after kill during attack-move

**Files:**
- Modify: `tests/unit/test_attack_move.gd`
- Verify: `scripts/units/unit_base.gd` (resume logic already in `_process_attacking` from Task 1 Step 7)

**Step 1: Write the test**

Add to `test_attack_move.gd`:

```gdscript
func test_attack_move_resumes_after_kill() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	attacker.attack_move_to(Vector2(500, 0))
	# Let attacker detect and engage
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		attacker._state, UnitBase.UnitState.ATTACKING,
		"should be attacking the enemy"
	)
	# Kill enemy
	enemy.take_damage(enemy.max_health)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		attacker._state, UnitBase.UnitState.ATTACK_MOVING,
		"should resume ATTACK_MOVING after target dies"
	)
	assert_true(
		attacker._has_attack_move_destination,
		"should still have attack move destination"
	)
```

**Step 2: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_attack_move.gd::test_attack_move_resumes_after_kill`

Expected: PASS — the resume logic was already implemented in Task 1 Step 7 (`_process_attacking` checks `_has_attack_move_destination`).

If this FAILS, debug by checking `_process_attacking` has the `_has_attack_move_destination` branch.

**Step 3: Commit**

```bash
git add tests/unit/test_attack_move.gd
git commit -m "test: add resume-after-kill test for attack-move (SPI-1371)"
```

---

### Task 5: Remaining attack-move tests

**Files:**
- Modify: `tests/unit/test_attack_move.gd`

**Step 1: Add test for idle on arrival**

```gdscript
func test_attack_move_idles_on_arrival() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	# Attack-move to a very close position (just past ARRIVAL_THRESHOLD)
	unit.attack_move_to(Vector2(10, 0))
	# Process enough frames for arrival
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		unit._state, UnitBase.UnitState.IDLE,
		"should be IDLE after arriving at attack-move destination"
	)
	assert_false(
		unit._has_attack_move_destination,
		"_has_attack_move_destination should be cleared on arrival"
	)
```

**Step 2: Add test for move_to clearing attack-move**

```gdscript
func test_move_to_clears_attack_move() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.attack_move_to(Vector2(500, 0))
	assert_true(unit._has_attack_move_destination)
	# Issue regular move command
	unit.move_to(Vector2(200, 0))
	assert_eq(
		unit._state, UnitBase.UnitState.MOVING,
		"move_to should override to MOVING state"
	)
	assert_false(
		unit._has_attack_move_destination,
		"move_to should clear _has_attack_move_destination"
	)
```

**Step 3: Run all attack-move tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_attack_move.gd`

Expected: All 6 tests PASS.

**Step 4: Format and lint**

Run: `gdformat tests/unit/test_attack_move.gd && gdlint tests/unit/test_attack_move.gd`

**Step 5: Commit**

```bash
git add tests/unit/test_attack_move.gd
git commit -m "test: add remaining attack-move tests (SPI-1371)"
```

---

### Task 6: Wire A-click input in main.gd

**Files:**
- Modify: `scripts/main.gd`

**Step 1: Add attack-move pending state and handler**

Add the variable after existing vars:

```gdscript
var _attack_move_pending: bool = false
```

**Step 2: Handle the A key press in `_unhandled_input()`**

Add before the `command` handler:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_select(event.position)
		else:
			_end_select(event.position)
	elif event is InputEventMouseMotion and _is_select_pressed:
		_update_drag(event.position)
	elif event.is_action_pressed("attack_move"):
		_attack_move_pending = true
	elif event.is_action_pressed("command"):
		_handle_command()
```

**Step 3: Intercept attack-move in click handler**

At the top of `_handle_click_select()`:

```gdscript
func _handle_click_select() -> void:
	if _attack_move_pending:
		_attack_move_pending = false
		_issue_attack_move()
		return
	# ... existing click-select logic unchanged ...
```

**Step 4: Add `_issue_attack_move()` method**

```gdscript
func _issue_attack_move() -> void:
	var click_pos := get_global_mouse_position()
	var selected := SelectionManager.get_selected_units()
	for unit in selected:
		if is_instance_valid(unit):
			unit.attack_move_to(click_pos)
```

**Step 5: Format and lint**

Run: `gdformat scripts/main.gd && gdlint scripts/main.gd`

**Step 6: Run all tests**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS.

**Step 7: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: wire A-click input for attack-move command (SPI-1371)"
```

---

### Task 7: Final verification and cleanup

**Files:**
- All modified files

**Step 1: Run full test suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS (test_unit_health, test_unit_death, test_unit_auto_attack, test_unit_selection, test_selection_manager, test_drag_select, test_attack_move).

**Step 2: Format check all touched files**

Run: `gdformat --check scripts/units/unit_base.gd scripts/main.gd tests/unit/test_attack_move.gd`

Expected: All files formatted correctly.

**Step 3: Lint all touched files**

Run: `gdlint scripts/units/unit_base.gd scripts/main.gd`

Expected: No problems found.

**Step 4: Manual smoke test**

Run: `godot --path . scenes/main/main.tscn`

Verify:
1. Select player units, right-click to move — works as before (no regression)
2. Select units, press A, click past enemy units — units walk, engage enemies in range, resume path after kill
3. If enemy retreats out of range, units resume immediately
4. Units idle when they reach the A-click destination
5. Regular right-click still does plain move (no attack behavior during move)
