# Godot RTS Development Patterns

## Unit Selection System

```gdscript
# Selection manager pattern
signal selection_changed(units: Array[Unit])

var selected_units: Array[Unit] = []

func select_unit(unit: Unit, add_to_selection: bool = false) -> void:
    if not add_to_selection:
        clear_selection()
    if unit not in selected_units:
        selected_units.append(unit)
        unit.set_selected(true)
    selection_changed.emit(selected_units)

func box_select(rect: Rect2) -> void:
    clear_selection()
    for unit in get_tree().get_nodes_in_group("selectable"):
        if rect.has_point(unit.global_position):
            selected_units.append(unit)
            unit.set_selected(true)
    selection_changed.emit(selected_units)
```

## Command Pattern for Unit Orders

```gdscript
class_name UnitCommand extends RefCounted

var target_position: Vector2
var target_unit: Unit
var command_type: CommandType

enum CommandType { MOVE, ATTACK, GATHER, HOLD }

func execute(unit: Unit) -> void:
    match command_type:
        CommandType.MOVE:
            unit.move_to(target_position)
        CommandType.ATTACK:
            unit.attack_target(target_unit)
        CommandType.GATHER:
            unit.gather_from(target_unit)
```

## Resource Node Pattern

```gdscript
class_name ResourceNode extends StaticBody2D

signal depleted
signal regenerated

@export var max_resources: int = 100
@export var regen_rate: float = 1.0
@export var regen_delay: float = 5.0

var current_resources: int = max_resources
var _regen_timer: float = 0.0

func harvest(amount: int) -> int:
    var harvested = mini(amount, current_resources)
    current_resources -= harvested
    if current_resources <= 0:
        depleted.emit()
        _regen_timer = regen_delay
    return harvested
```

## Control Point Capture

```gdscript
class_name ControlPoint extends Area2D

signal captured(team: int)
signal contested

@export var capture_time: float = 5.0

var owning_team: int = -1
var capturing_team: int = -1
var capture_progress: float = 0.0

func _physics_process(delta: float) -> void:
    var teams_present = _get_teams_in_zone()

    if teams_present.size() == 1:
        var team = teams_present[0]
        if team != owning_team:
            capturing_team = team
            capture_progress += delta / capture_time
            if capture_progress >= 1.0:
                _complete_capture(team)
    elif teams_present.size() > 1:
        contested.emit()
        capture_progress = 0.0
```

## Fog of War (Shader-based)

```gdscript
# Reveal areas around units
func update_fog() -> void:
    var reveal_points: Array[Vector2] = []
    for unit in get_tree().get_nodes_in_group("player_units"):
        reveal_points.append(unit.global_position)
    fog_shader.set_shader_parameter("reveal_points", reveal_points)
```

## Event Bus Pattern

```gdscript
# autoload/event_bus.gd
extends Node

signal unit_spawned(unit: Unit)
signal unit_died(unit: Unit)
signal resources_changed(amount: int)
signal control_point_captured(point: ControlPoint, team: int)
signal victory(winning_team: int)

# Systems connect to these signals for loose coupling
```

## State Machine for Units

```gdscript
enum UnitState { IDLE, MOVING, ATTACKING, GATHERING, DEAD }

var current_state: UnitState = UnitState.IDLE

func _physics_process(delta: float) -> void:
    match current_state:
        UnitState.IDLE:
            _process_idle(delta)
        UnitState.MOVING:
            _process_moving(delta)
        UnitState.ATTACKING:
            _process_attacking(delta)
        UnitState.GATHERING:
            _process_gathering(delta)

func change_state(new_state: UnitState) -> void:
    _exit_state(current_state)
    current_state = new_state
    _enter_state(new_state)
```
