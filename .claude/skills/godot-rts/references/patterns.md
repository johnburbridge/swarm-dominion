# RTS Implementation Patterns

Detailed code patterns for Swarm Dominion RTS mechanics.

## Unit Selection System

Complete selection manager implementation supporting single-click, box selection, and control groups.

```gdscript
class_name SelectionManager extends Node

signal selection_changed(units: Array[Unit])

var selected_units: Array[Unit] = []
var control_groups: Dictionary = {}  # int -> Array[Unit]

func select_unit(unit: Unit, add_to_selection: bool = false) -> void:
    if not add_to_selection:
        _clear_selection()
    if unit not in selected_units:
        selected_units.append(unit)
        unit.set_selected(true)
    selection_changed.emit(selected_units)


func _clear_selection() -> void:
    for unit in selected_units:
        unit.set_selected(false)
    selected_units.clear()


func box_select(screen_rect: Rect2, camera: Camera2D) -> void:
    _clear_selection()
    for unit in get_tree().get_nodes_in_group("selectable"):
        var screen_pos = camera.unproject_position(unit.global_position)
        if screen_rect.has_point(screen_pos):
            selected_units.append(unit)
            unit.set_selected(true)
    selection_changed.emit(selected_units)


func assign_control_group(group_number: int) -> void:
    control_groups[group_number] = selected_units.duplicate()


func recall_control_group(group_number: int) -> void:
    if group_number in control_groups:
        _clear_selection()
        selected_units = control_groups[group_number].duplicate()
        for unit in selected_units:
            if is_instance_valid(unit):
                unit.set_selected(true)
        selection_changed.emit(selected_units)


func get_selected_count() -> int:
    return selected_units.size()


func has_selection() -> bool:
    return not selected_units.is_empty()
```

## Unit State Machine

Enum-based state machine with enter/exit/process pattern.

```gdscript
class_name UnitStateMachine extends Node

enum State { IDLE, MOVING, ATTACKING, GATHERING, DEAD }

var current_state: State = State.IDLE
var unit: Unit  # Reference to parent unit

func _ready() -> void:
    unit = get_parent() as Unit


func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:
            _process_idle(delta)
        State.MOVING:
            _process_moving(delta)
        State.ATTACKING:
            _process_attacking(delta)
        State.GATHERING:
            _process_gathering(delta)
        State.DEAD:
            pass  # No processing when dead


func change_state(new_state: State) -> void:
    if current_state == new_state:
        return
    _exit_state(current_state)
    current_state = new_state
    _enter_state(new_state)


func _enter_state(state: State) -> void:
    match state:
        State.IDLE:
            unit.animation_player.play("idle")
        State.MOVING:
            unit.animation_player.play("walk")
        State.ATTACKING:
            unit.animation_player.play("attack")
        State.GATHERING:
            unit.animation_player.play("gather")
        State.DEAD:
            unit.animation_player.play("death")
            unit.set_process(false)


func _exit_state(state: State) -> void:
    match state:
        State.ATTACKING:
            unit.current_target = null
        State.GATHERING:
            unit.current_resource_node = null


func _process_idle(_delta: float) -> void:
    # Check for nearby enemies to auto-attack
    var enemy = unit.find_nearest_enemy()
    if enemy and unit.is_in_attack_range(enemy):
        unit.current_target = enemy
        change_state(State.ATTACKING)


func _process_moving(delta: float) -> void:
    if unit.navigation_agent.is_navigation_finished():
        change_state(State.IDLE)
    else:
        var next_pos = unit.navigation_agent.get_next_path_position()
        var direction = (next_pos - unit.global_position).normalized()
        unit.velocity = direction * unit.move_speed
        unit.move_and_slide()


func _process_attacking(delta: float) -> void:
    if not is_instance_valid(unit.current_target):
        change_state(State.IDLE)
        return

    if not unit.is_in_attack_range(unit.current_target):
        # Move closer to target
        unit.navigation_agent.target_position = unit.current_target.global_position
        change_state(State.MOVING)
        return

    # Attack logic handled by animation events


func _process_gathering(delta: float) -> void:
    if not is_instance_valid(unit.current_resource_node):
        change_state(State.IDLE)
        return

    if unit.current_resource_node.is_depleted():
        change_state(State.IDLE)
        return

    # Gathering progress handled by timer
```

## Command Pattern

Command objects for unit orders with queue support.

```gdscript
class_name UnitCommand extends RefCounted

enum Type { MOVE, ATTACK, GATHER, HOLD, STOP }

var command_type: Type
var target_position: Vector2
var target_unit: Node2D
var target_resource: ResourceNode


static func move_to(position: Vector2) -> UnitCommand:
    var cmd = UnitCommand.new()
    cmd.command_type = Type.MOVE
    cmd.target_position = position
    return cmd


static func attack(target: Node2D) -> UnitCommand:
    var cmd = UnitCommand.new()
    cmd.command_type = Type.ATTACK
    cmd.target_unit = target
    return cmd


static func gather(resource: ResourceNode) -> UnitCommand:
    var cmd = UnitCommand.new()
    cmd.command_type = Type.GATHER
    cmd.target_resource = resource
    return cmd


static func hold() -> UnitCommand:
    var cmd = UnitCommand.new()
    cmd.command_type = Type.HOLD
    return cmd


static func stop() -> UnitCommand:
    var cmd = UnitCommand.new()
    cmd.command_type = Type.STOP
    return cmd


func execute(unit: Unit) -> void:
    match command_type:
        Type.MOVE:
            unit.move_to(target_position)
        Type.ATTACK:
            unit.attack_target(target_unit)
        Type.GATHER:
            unit.gather_from(target_resource)
        Type.HOLD:
            unit.hold_position()
        Type.STOP:
            unit.stop_current_action()


func serialize() -> Dictionary:
    return {
        "type": command_type,
        "position": [target_position.x, target_position.y] if target_position else null,
        "target_id": target_unit.get_instance_id() if target_unit else null,
        "resource_id": target_resource.get_instance_id() if target_resource else null,
    }
```

## Control Point Capture

Zone-based capture with contested state handling.

```gdscript
class_name ControlPoint extends Area2D

signal captured(team: int)
signal contested
signal capture_progress_changed(progress: float)

@export var capture_time: float = 5.0
@export var vision_radius: float = 200.0

var owning_team: int = -1  # -1 = neutral
var capturing_team: int = -1
var capture_progress: float = 0.0

var _units_in_zone: Array[Unit] = []


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
    var teams_present = _get_teams_in_zone()

    if teams_present.is_empty():
        # No units - progress decays
        if capture_progress > 0:
            capture_progress = maxf(0, capture_progress - delta / capture_time)
            capture_progress_changed.emit(capture_progress)
        return

    if teams_present.size() > 1:
        # Contested - no progress, emit signal
        contested.emit()
        return

    var team = teams_present[0]

    if team == owning_team:
        # Owning team present - no change needed
        return

    # Enemy team capturing
    if capturing_team != team:
        # New capturing team - reset progress
        capturing_team = team
        capture_progress = 0.0

    capture_progress += delta / capture_time
    capture_progress_changed.emit(capture_progress)

    if capture_progress >= 1.0:
        _complete_capture(team)


func _get_teams_in_zone() -> Array[int]:
    var teams: Array[int] = []
    for unit in _units_in_zone:
        if is_instance_valid(unit) and unit.team not in teams:
            teams.append(unit.team)
    return teams


func _complete_capture(team: int) -> void:
    owning_team = team
    capturing_team = -1
    capture_progress = 0.0
    captured.emit(team)
    EventBus.control_point_captured.emit(self, team)


func _on_body_entered(body: Node2D) -> void:
    if body is Unit:
        _units_in_zone.append(body)


func _on_body_exited(body: Node2D) -> void:
    if body is Unit:
        _units_in_zone.erase(body)


func get_vision_points() -> Array[Vector2]:
    if owning_team >= 0:
        return [global_position]
    return []
```

## Resource Node (Biomass)

Harvestable resource with depletion and regeneration.

```gdscript
class_name ResourceNode extends StaticBody2D

signal depleted
signal regenerated
signal resources_changed(current: int, maximum: int)

@export var max_resources: int = 100
@export var harvest_amount: int = 10
@export var regen_rate: float = 2.0  # Per second
@export var regen_delay: float = 5.0  # Seconds after depletion

var current_resources: int
var _regen_timer: float = 0.0
var _is_depleted: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: GPUParticles2D = $HarvestParticles


func _ready() -> void:
    current_resources = max_resources
    _update_visual()


func _process(delta: float) -> void:
    if _is_depleted:
        _regen_timer -= delta
        if _regen_timer <= 0:
            _start_regenerating()
    elif current_resources < max_resources:
        current_resources = mini(current_resources + int(regen_rate * delta), max_resources)
        resources_changed.emit(current_resources, max_resources)
        _update_visual()

        if current_resources >= max_resources:
            regenerated.emit()


func harvest(harvester: Unit) -> int:
    if _is_depleted:
        return 0

    var harvested = mini(harvest_amount, current_resources)
    current_resources -= harvested
    resources_changed.emit(current_resources, max_resources)

    particles.emitting = true
    _update_visual()

    if current_resources <= 0:
        _is_depleted = true
        _regen_timer = regen_delay
        depleted.emit()

    return harvested


func is_depleted() -> bool:
    return _is_depleted


func _start_regenerating() -> void:
    _is_depleted = false
    current_resources = 1
    _update_visual()


func _update_visual() -> void:
    var fill_ratio = float(current_resources) / max_resources
    sprite.modulate.a = 0.3 + (fill_ratio * 0.7)

    if _is_depleted:
        sprite.modulate = Color(0.5, 0.5, 0.5, 0.3)
    else:
        sprite.modulate = Color(1, 1, 1, 0.3 + (fill_ratio * 0.7))
```

## Fog of War

Shader-based fog with unit vision reveal.

```gdscript
class_name FogOfWar extends CanvasLayer

@export var fog_color: Color = Color(0, 0, 0, 0.8)
@export var explored_color: Color = Color(0, 0, 0, 0.4)

var _vision_points: Array[Dictionary] = []  # {position: Vector2, radius: float}
var _explored_cells: Dictionary = {}  # Vector2i -> bool
var _cell_size: int = 32

@onready var fog_texture: TextureRect = $FogTexture


func _ready() -> void:
    _setup_fog_shader()


func _process(_delta: float) -> void:
    _update_vision_points()
    _update_fog_shader()


func _update_vision_points() -> void:
    _vision_points.clear()

    # Get vision from player units
    for unit in get_tree().get_nodes_in_group("player_units"):
        _vision_points.append({
            "position": unit.global_position,
            "radius": unit.vision_radius
        })
        _mark_explored(unit.global_position, unit.vision_radius)

    # Get vision from owned control points
    for point in get_tree().get_nodes_in_group("control_points"):
        if point.owning_team == GameManager.player_team:
            for pos in point.get_vision_points():
                _vision_points.append({
                    "position": pos,
                    "radius": point.vision_radius
                })
                _mark_explored(pos, point.vision_radius)


func _mark_explored(position: Vector2, radius: float) -> void:
    var cell_radius = int(radius / _cell_size) + 1
    var center_cell = Vector2i(position / _cell_size)

    for x in range(-cell_radius, cell_radius + 1):
        for y in range(-cell_radius, cell_radius + 1):
            var cell = center_cell + Vector2i(x, y)
            var cell_center = Vector2(cell) * _cell_size + Vector2(_cell_size / 2, _cell_size / 2)
            if position.distance_to(cell_center) <= radius:
                _explored_cells[cell] = true


func _setup_fog_shader() -> void:
    var material = ShaderMaterial.new()
    material.shader = preload("res://assets/shaders/fog_of_war.gdshader")
    fog_texture.material = material


func _update_fog_shader() -> void:
    var material = fog_texture.material as ShaderMaterial

    var positions: PackedVector2Array = []
    var radii: PackedFloat32Array = []

    for point in _vision_points:
        positions.append(point.position)
        radii.append(point.radius)

    material.set_shader_parameter("vision_positions", positions)
    material.set_shader_parameter("vision_radii", radii)
    material.set_shader_parameter("vision_count", _vision_points.size())


func is_position_visible(position: Vector2) -> bool:
    for point in _vision_points:
        if position.distance_to(point.position) <= point.radius:
            return true
    return false


func is_position_explored(position: Vector2) -> bool:
    var cell = Vector2i(position / _cell_size)
    return cell in _explored_cells
```

## Combat System

Damage calculation with team checking.

```gdscript
class_name CombatSystem extends Node

func calculate_damage(attacker: Unit, defender: Unit) -> int:
    var base_damage = attacker.attack_damage

    # Apply upgrades
    base_damage = int(base_damage * attacker.damage_multiplier)

    # Apply armor reduction
    var armor = defender.armor
    var damage_reduction = armor / (armor + 100.0)  # Diminishing returns
    var final_damage = int(base_damage * (1.0 - damage_reduction))

    return maxi(1, final_damage)  # Minimum 1 damage


func can_attack(attacker: Unit, target: Unit) -> bool:
    # Can't attack same team
    if attacker.team == target.team:
        return false

    # Check if target is valid
    if not is_instance_valid(target):
        return false

    # Check if target is visible (fog of war)
    if not GameManager.fog_of_war.is_position_visible(target.global_position):
        return false

    return true


func apply_damage(attacker: Unit, defender: Unit) -> void:
    if not can_attack(attacker, defender):
        return

    var damage = calculate_damage(attacker, defender)
    defender.take_damage(damage, attacker)

    EventBus.damage_dealt.emit(attacker, defender, damage)
```
