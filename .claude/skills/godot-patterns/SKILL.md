---
description: Use when implementing GDScript code, unit behaviors, game systems, or mechanics in Swarm Dominion. Provides Godot 4.x patterns and project-specific conventions.
---

# Godot Patterns for Swarm Dominion

This skill provides domain knowledge for implementing game features in Swarm Dominion using Godot 4.x and GDScript.

## Project Architecture

### Node Hierarchy

```
Main (Node2D)
├── Units (Node2D) - Container for all units
│   └── UnitBase (CharacterBody2D) - Base class for units
├── Systems (Node) - Game systems container
└── UI (CanvasLayer) - UI elements
```

### Autoloads (Singletons)

| Autoload | Purpose |
|----------|---------|
| `EventBus` | Signal-based communication between systems |
| `GameManager` | Game state, win conditions, match flow |
| `AudioManager` | Sound effects and music |

### Key Base Classes

| Class | Extends | Purpose |
|-------|---------|---------|
| `UnitBase` | `CharacterBody2D` | All game units (drones, hunters, etc.) |

## GDScript Conventions

### Naming

```gdscript
class_name UnitBase extends CharacterBody2D

const MAX_HEALTH: int = 100          # UPPER_SNAKE_CASE for constants
@export var move_speed: float = 200.0 # snake_case for variables

var _private_var: String             # Leading underscore for private
var _is_moving: bool = false         # Boolean prefixed with is_/has_/can_

@onready var _sprite: Sprite2D = $Sprite2D  # @onready for node refs
```

### Type Hints

Always use type hints for:
- Function parameters
- Function return types
- Class variables

```gdscript
func move_to(target: Vector2) -> void:
    _target_position = target
    _is_moving = true

func get_health() -> int:
    return _current_health
```

### Signal Definitions

Define signals at the top of the class:

```gdscript
class_name UnitBase extends CharacterBody2D

signal health_changed(new_health: int)
signal died

@export var max_health: int = 100
```

## Common Patterns

### Movement Pattern

Units use `CharacterBody2D` with `move_and_slide()` for physics-based movement:

1. Track target position and moving state
2. Calculate direction in `_physics_process()`
3. Set velocity and call `move_and_slide()`
4. Use arrival threshold to prevent jitter

See: `examples/unit-movement.md`

### Input Handling Pattern

Use `_unhandled_input()` for game commands (allows UI to consume first):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("command"):
        var click_position = get_global_mouse_position()
        # Handle command...
```

Input actions are defined in `project.godot`:
- `select` - Left mouse button
- `command` - Right mouse button
- `attack_move` - A key
- `camera_up/down/left/right` - WASD keys

### Group Membership Pattern

Use groups for unit queries:

```gdscript
func _ready() -> void:
    add_to_group("units")
    add_to_group("player_units")  # or "enemy_units"

# Query all units
var all_units = get_tree().get_nodes_in_group("units")
```

## Examples Index

Detailed implementation examples with code snippets and rationale:

| Example | Pattern | Source |
|---------|---------|--------|
| [unit-movement.md](examples/unit-movement.md) | Click-to-move with arrival detection | SPI-1349 |

## References

- Project conventions: See `CLAUDE.md` in project root
- Game design: See `docs/PRD.md` for full requirements
- Godot docs: https://docs.godotengine.org/en/stable/
