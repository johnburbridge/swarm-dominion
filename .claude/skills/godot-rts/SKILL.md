---
name: godot-rts
description: This skill should be used when the user asks to "implement unit selection", "add pathfinding", "create a state machine for units", "implement fog of war", "add control point capture", "create resource gathering", "implement combat system", or when working on RTS game mechanics in Godot 4.x. Provides patterns and architecture guidance for Swarm Dominion development.
---

# Godot RTS Development Patterns

Architectural patterns and implementation guidance for Swarm Dominion, a real-time strategy game built with Godot 4.x.

## When to Use This Skill

Apply these patterns when implementing:
- Unit selection and control systems
- Command/order processing for units
- Resource gathering mechanics
- Control point capture systems
- Fog of war visibility
- Unit state machines
- Event-driven architecture

## Core Architecture Principles

### Signal-Based Communication

Decouple systems using Godot's signal system. Define signals at the top of each class and emit them for state changes. Other systems connect to these signals rather than directly referencing each other.

```gdscript
# Define signals at class top
signal health_changed(new_health: int)
signal unit_died

# Emit on state change
func take_damage(amount: int) -> void:
    current_health -= amount
    health_changed.emit(current_health)
    if current_health <= 0:
        unit_died.emit()
```

### EventBus Pattern

Use the global EventBus autoload for cross-system communication. Systems subscribe to relevant events without direct coupling.

```gdscript
# In any system - connect to events
func _ready() -> void:
    EventBus.unit_spawned.connect(_on_unit_spawned)
    EventBus.control_point_captured.connect(_on_point_captured)
```

See `scripts/autoload/event_bus.gd` for the full signal list.

### Data-Driven Design

Store unit stats, costs, and balance values in JSON files under `data/`. Load at runtime to enable easy tuning without code changes.

```gdscript
var unit_stats: Dictionary

func _ready() -> void:
    var file = FileAccess.open("res://data/unit_stats.json", FileAccess.READ)
    unit_stats = JSON.parse_string(file.get_as_text())
```

## Implementation Patterns

### Unit Selection System

Implement selection with a dedicated manager that tracks selected units and emits changes. Support single-click selection, box selection, and control groups.

Key components:
- `selected_units: Array[Unit]` - Currently selected units
- `selection_changed` signal - Notify UI and other systems
- Box selection via `Rect2.has_point()`
- Control groups stored in dictionary by number key

See `references/patterns.md` for complete implementation.

### Unit State Machine

Use an enum-based state machine for unit behavior. Each state has enter/exit/process methods. Transitions go through a central `change_state()` function.

States for Swarm Dominion units:
- `IDLE` - Waiting for orders
- `MOVING` - Pathfinding to target
- `ATTACKING` - Engaging enemy
- `GATHERING` - Harvesting resources
- `DEAD` - Playing death animation

See `references/patterns.md` for state machine template.

### Command Pattern

Encapsulate unit orders as command objects. This enables:
- Command queuing (shift-click)
- Command history for replays
- Network serialization for multiplayer

Command types: `MOVE`, `ATTACK`, `GATHER`, `HOLD`, `STOP`

### Control Point Capture

Capture mechanics based on PRD:
- Units in zone with no enemies = capturing
- Multiple teams present = contested (no progress)
- Progress resets when contested
- Single unit captures at same rate as multiple

### Resource Gathering

Biomass nodes with:
- Depletion on harvest
- Regeneration after delay
- Visual feedback for state
- Signals for UI updates

## Project-Specific Conventions

### File Organization

| Type | Location | Naming |
|------|----------|--------|
| Scenes | `scenes/{category}/` | `snake_case.tscn` |
| Scripts | `scripts/{category}/` | `snake_case.gd` |
| Unit scenes | `scenes/units/` | `drone.tscn`, `mother.tscn` |
| System scripts | `scripts/systems/` | `resource_system.gd` |

### GDScript Style

Follow project conventions in CLAUDE.md:
- `class_name PascalCase`
- `const UPPER_SNAKE_CASE`
- `var snake_case` with type hints
- `func snake_case()` with return type hints
- `_leading_underscore` for private members

### Node References

Use `@onready` for node references, not `$Node` in `_ready()`:

```gdscript
@onready var health_bar: ProgressBar = $HealthBar
@onready var sprite: Sprite2D = $Sprite2D
```

## Additional Resources

### Reference Files

For detailed implementation patterns:
- **`references/patterns.md`** - Complete code patterns for selection, state machines, commands, and more

### Example Files

Working examples in `examples/`:
- **`examples/unit_base.gd`** - Base unit class template
- **`examples/selection_manager.gd`** - Selection system implementation

### Project Documentation

- **`docs/PRD.md`** - Full game design and requirements
- **`data/unit_stats.json`** - Unit balance values
- **`data/upgrade_costs.json`** - Upgrade progression costs
