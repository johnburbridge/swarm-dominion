# Unit Movement Pattern

**Source:** SPI-1349 - Unit Moves to Clicked Map Location
**Files:** `scripts/units/unit_base.gd`, `scripts/main.gd`

## Overview

Click-to-move pattern using `CharacterBody2D` with arrival detection and sprite rotation.

## Key Design Decisions

### 1. Arrival Threshold (5.0 pixels)

```gdscript
const ARRIVAL_THRESHOLD: float = 5.0
```

**Why:** Prevents oscillation/jitter when unit reaches destination. Without a threshold, floating-point imprecision causes the unit to overshoot and continuously correct.

**Trade-off:** Higher values feel "close enough" sooner but less precise. 5.0 pixels is imperceptible at 1080p.

### 2. Movement State Flag

```gdscript
var _is_moving: bool = false
```

**Why:** Early exit in `_physics_process()` when not moving. Avoids unnecessary calculations every frame.

```gdscript
func _physics_process(_delta: float) -> void:
    if not _is_moving:
        return
    # ... movement logic
```

### 3. Using `move_and_slide()`

**Why chosen over alternatives:**

| Method | Pros | Cons |
|--------|------|------|
| `move_and_slide()` | Handles collisions, smooth movement | Requires CharacterBody2D |
| Direct `position +=` | Simple | No collision, can clip through objects |
| `move_and_collide()` | More control | Must handle slide logic manually |

`move_and_slide()` is the standard for units that need collision response - foundation for future pathfinding and obstacle avoidance.

### 4. Sprite Rotation for Facing

```gdscript
_sprite.rotation = direction.angle()
```

**Why:** Visual feedback that unit is moving in intended direction. Uses `angle()` which returns radians - Godot's rotation property expects radians.

**Note:** Assumes sprite's "forward" is pointing right (0 radians). If sprite points up, add `PI/2` offset.

## Implementation

### UnitBase (scripts/units/unit_base.gd)

```gdscript
class_name UnitBase extends CharacterBody2D
## Base class for all game units.
## Provides common functionality like movement and group membership.

## Movement speed in pixels per second
@export var move_speed: float = 200.0

## Threshold distance to consider "arrived" at target
const ARRIVAL_THRESHOLD: float = 5.0

var _target_position: Vector2
var _is_moving: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
    add_to_group("units")
    _target_position = position


func _physics_process(_delta: float) -> void:
    if not _is_moving:
        return

    var distance = position.distance_to(_target_position)

    if distance <= ARRIVAL_THRESHOLD:
        _is_moving = false
        velocity = Vector2.ZERO
        return

    var direction = (_target_position - position).normalized()
    velocity = direction * move_speed

    # Face movement direction
    _sprite.rotation = direction.angle()

    move_and_slide()


func move_to(target: Vector2) -> void:
    # Prevent jitter when clicking current position
    if position.distance_to(target) <= ARRIVAL_THRESHOLD:
        return
    _target_position = target
    _is_moving = true
```

### Input Handling (scripts/main.gd)

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("command"):
        var click_position = get_global_mouse_position()
        if _test_drone:
            _test_drone.move_to(click_position)
```

**Why `_unhandled_input()`:** Allows UI elements to consume input first. If a button is clicked, the game won't also issue a move command.

**Why `get_global_mouse_position()`:** Returns position in world coordinates, not screen coordinates. Works correctly regardless of camera position or zoom.

## Acceptance Criteria Satisfied

| Criteria | How |
|----------|-----|
| Unit moves toward clicked location | `move_to()` sets target, `_physics_process()` moves unit |
| Unit faces movement direction | `_sprite.rotation = direction.angle()` |
| Unit stops at destination | Arrival threshold check sets `_is_moving = false` |
| New click interrupts movement | `move_to()` overwrites `_target_position` |
| No jitter on current position | `move_to()` early-returns if already at target |

## Future Extensions

When implementing additional movement features:

- **Pathfinding:** Replace direct movement with NavigationAgent2D, keep same `move_to()` interface
- **Formation movement:** Calculate offset positions, call `move_to()` with adjusted targets
- **Attack-move:** Add state machine, check for enemies while moving
- **Smoothing:** Add acceleration/deceleration by lerping `move_speed`
