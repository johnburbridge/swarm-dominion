# Design: SPI-1371 — Attack-Move Command (A+click)

**Issue:** SPI-1371
**Branch:** `johnburbridge/spi-1371-implement-attack-move-command-aclick`
**Date:** 2026-02-16

## Overview

Add attack-move functionality: press A then left-click a destination. Selected units move toward the target while engaging enemies encountered along the way. After killing an enemy, the unit resumes its path. No chasing — if an enemy leaves attack range, the unit continues moving.

This feature requires refactoring `unit_base.gd` from implicit boolean state (`_is_moving`, `_is_dead`) to an explicit state machine enum.

## Design Decisions

- **Resume after kill:** Unit continues toward original destination after target dies or leaves range.
- **No chase:** Unit only fights enemies within attack range (80px for drones). If enemy retreats, unit resumes path.
- **State machine refactor:** Replace `_is_moving`/`_is_dead` booleans with `UnitState` enum. Cleaner architecture that scales to future behaviors.
- **Input pattern:** A key sets pending mode, next left-click issues attack-move (standard RTS convention). The `attack_move` input action is already mapped in project.godot.

## State Machine

```gdscript
enum UnitState { IDLE, MOVING, ATTACKING, ATTACK_MOVING, DEAD }
var _state: UnitState = UnitState.IDLE
```

### Transitions

```
IDLE ──move_to()──> MOVING ──arrives──> IDLE
  |
  |──enemy in range──> ATTACKING ──target lost──> IDLE
  |
  └──attack_move_to()──> ATTACK_MOVING ──enemy in range──> ATTACKING
                              |                                |
                              └──arrives──> IDLE          target lost──> ATTACK_MOVING
                                                          (resume toward saved destination)
```

### `_physics_process` dispatch

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
            _process_attack_moving(delta)
        UnitState.DEAD:
            pass
```

## New Methods on `unit_base.gd`

### `attack_move_to(target: Vector2)`

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

### `_process_attack_moving(delta: float)`

Combines movement and target scanning each frame:

```gdscript
func _process_attack_moving(delta: float) -> void:
    if _attack_target == null:
        _try_acquire_target()
    if _attack_target != null:
        _state = UnitState.ATTACKING
        return
    _process_movement()
```

### Resume logic in `_process_attacking`

When the attack target is lost (dies or leaves range):

```gdscript
if _has_attack_move_destination:
    _state = UnitState.ATTACK_MOVING  # Resume toward saved _target_position
else:
    _state = UnitState.IDLE
```

## Refactoring `_is_dead` / `_is_moving`

### `_is_dead` backward compatibility

Keep as a computed property so existing tests and `_is_valid_target()` work unchanged:

```gdscript
var _is_dead: bool:
    get:
        return _state == UnitState.DEAD
```

### `_is_moving` removal

Replace all internal references with `_state == UnitState.MOVING or _state == UnitState.ATTACK_MOVING`. The `_is_moving` variable is only used internally in `unit_base.gd` (movement processing, animation), so this is a contained change.

### `move_to()` update

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

### `_die()` update

```gdscript
func _die() -> void:
    _state = UnitState.DEAD
    # ... rest of existing death logic unchanged ...
```

## Input Flow in `main.gd`

### Attack-move pending state

```gdscript
var _attack_move_pending: bool = false

func _unhandled_input(event: InputEvent) -> void:
    # ... existing mouse handling ...
    elif event.is_action_pressed("attack_move"):
        _attack_move_pending = true
    elif event.is_action_pressed("command"):
        _handle_command()
```

### Intercept in click handler

In `_handle_click_select()`, before normal selection logic:

```gdscript
func _handle_click_select() -> void:
    if _attack_move_pending:
        _attack_move_pending = false
        _issue_attack_move()
        return
    # ... existing selection logic ...
```

### Issue attack-move command

```gdscript
func _issue_attack_move() -> void:
    var click_pos := get_global_mouse_position()
    for unit in SelectionManager.get_selected_units():
        if is_instance_valid(unit):
            unit.attack_move_to(click_pos)
```

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `scripts/units/unit_base.gd` | Edit | Add UnitState enum, refactor to state machine, add `attack_move_to()`, `_process_attack_moving()` |
| `scripts/main.gd` | Edit | Add `_attack_move_pending` flag, `_issue_attack_move()`, intercept in click handler |
| `tests/unit/test_attack_move.gd` | Create | 6 new tests for attack-move behavior |
| `tests/unit/test_unit_health.gd` | Edit | Update `_is_dead` checks if needed (may work as-is with getter) |
| `tests/unit/test_unit_death.gd` | Edit | Same — verify existing tests pass with getter |

## Tests

### `tests/unit/test_attack_move.gd`

| Test | Verifies |
|------|----------|
| `test_attack_move_sets_state` | `attack_move_to()` sets `_state` to `ATTACK_MOVING` |
| `test_attack_move_engages_enemy_in_range` | Unit transitions to `ATTACKING` when enemy enters range during movement |
| `test_attack_move_resumes_after_kill` | After target dies, unit returns to `ATTACK_MOVING` and continues toward destination |
| `test_attack_move_idles_on_arrival` | Unit transitions to `IDLE` when reaching destination with no enemies |
| `test_move_to_clears_attack_move` | Regular `move_to()` cancels attack-move (sets `_has_attack_move_destination = false`) |
| `test_dead_unit_ignores_attack_move` | `attack_move_to()` has no effect when `_state == DEAD` |

## Verification

```bash
godot --headless -s addons/gut/gut_cmdln.gd
gdformat --check scripts/units/unit_base.gd scripts/main.gd tests/unit/test_attack_move.gd
gdlint scripts/units/unit_base.gd scripts/main.gd
```

**Manual verification:**
1. Select units, press A, click a destination past enemies
2. Units walk toward destination, stop to fight enemies in range
3. After killing enemy, units resume walking
4. If enemy retreats out of range, units resume immediately
5. Units idle when they reach the destination
6. Regular right-click move still works (no attack-move behavior)
