# Design: SPI-1372 — Control Groups (Ctrl+number to assign, number to recall)

**Issue:** SPI-1372
**Date:** 2026-02-25

## Overview

Add control groups so players can assign selected units to numbered groups (Ctrl+1 through Ctrl+5) and instantly recall them by pressing the number key. Double-tapping a group number centers the camera on that group. Standard RTS convention adapted for Swarm Dominion's fast-paced design.

## Design Decisions

- **5 groups (keys 1-5):** Sufficient for short matches, avoids reaching for 6-0 keys.
- **Extend SelectionManager:** Control group state lives alongside selection state in the existing autoload. Simple, avoids a new autoload for ~30 lines of logic.
- **Raw key detection in main.gd:** Handle Ctrl+N / N via `InputEventKey` checks rather than 10 separate input actions in project.godot.
- **Double-tap for camera snap:** Track last recall group + time, snap camera if same group recalled within 300ms.
- **Silent death cleanup:** Dead units are automatically removed from groups via the existing `remove_unit()` path.
- **Multi-group membership:** A unit can belong to multiple groups simultaneously (StarCraft convention).
- **Assign replaces:** Ctrl+N overwrites whatever was previously in group N.

## Data Model

In `SelectionManager`:

```gdscript
const GROUP_COUNT: int = 5
var _control_groups: Array[Array] = [[], [], [], [], []]
```

Groups are indexed 0-4, mapped to keys 1-5.

## API (SelectionManager)

### `assign_group(index: int) -> void`

Saves the current selection to the given group slot (0-4). Replaces any previous contents.

```gdscript
func assign_group(index: int) -> void:
    if index < 0 or index >= GROUP_COUNT:
        return
    _control_groups[index] = _selected_units.duplicate()
```

### `recall_group(index: int) -> void`

Selects the units in the given group. Filters out any invalid/dead units first.

```gdscript
func recall_group(index: int) -> void:
    if index < 0 or index >= GROUP_COUNT:
        return
    var group: Array = _control_groups[index]
    var valid_units: Array[UnitBase] = []
    for unit in group:
        if is_instance_valid(unit) and not unit._is_dead:
            valid_units.append(unit)
    _control_groups[index].assign(valid_units)
    select_units(valid_units)
```

### `get_group_center(index: int) -> Vector2`

Returns the average position of units in the group, for camera centering. Returns `Vector2.ZERO` if group is empty.

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

## Death Cleanup

Extend `remove_unit()` to clean groups:

```gdscript
func remove_unit(unit: UnitBase) -> void:
    if unit in _selected_units:
        _selected_units.erase(unit)
        selection_changed.emit(_selected_units)
    for group in _control_groups:
        group.erase(unit)
```

## Input Handling (main.gd)

### Key detection in `_unhandled_input`

```gdscript
elif event is InputEventKey and event.pressed and not event.echo:
    var key := event.keycode
    if key >= KEY_1 and key <= KEY_5:
        var group_index := key - KEY_1
        if event.ctrl_pressed:
            SelectionManager.assign_group(group_index)
        else:
            _recall_group(group_index)
```

### Double-tap camera snap

Track in `main.gd`:

```gdscript
const DOUBLE_TAP_THRESHOLD: float = 0.3
var _last_recall_group: int = -1
var _last_recall_time: float = 0.0

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

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `scripts/autoload/selection_manager.gd` | Edit | Add `_control_groups`, `assign_group()`, `recall_group()`, `get_group_center()`, extend `remove_unit()` |
| `scripts/main.gd` | Edit | Add key detection for Ctrl+N / N, double-tap camera snap |
| `tests/unit/test_control_groups.gd` | Create | 6 tests for control group behavior |

## Tests

| Test | Verifies |
|------|----------|
| `test_assign_and_recall_group` | Ctrl+N saves current selection, N recalls it |
| `test_assign_replaces_previous_group` | Reassigning a group overwrites old contents |
| `test_recall_empty_group_does_nothing` | Recalling an empty group deselects all, no crash |
| `test_dead_unit_removed_from_group` | Unit death removes it from all groups |
| `test_unit_in_multiple_groups` | A unit can belong to groups 1 and 2 simultaneously |
| `test_group_center_calculation` | `get_group_center()` returns average position |

## Verification

```bash
godot --headless -s addons/gut/gut_cmdln.gd
gdformat --check scripts/autoload/selection_manager.gd scripts/main.gd tests/unit/test_control_groups.gd
gdlint scripts/autoload/selection_manager.gd scripts/main.gd
```

Manual: assign units to group 1, press 1 to recall, double-tap 1 to center camera.
