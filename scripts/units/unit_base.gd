class_name UnitBase extends CharacterBody2D
## Base class for all game units.
## Provides common functionality like movement, health, and auto-attack.

signal health_changed(current_health: int, max_health: int)
signal attack_started(target: Node)
signal attack_stopped

## Threshold distance to consider "arrived" at target
const ARRIVAL_THRESHOLD: float = 5.0

## Movement speed in pixels per second
@export var move_speed: float = 200.0
@export var team_id: int = 0
@export var unit_type: String = "drone"

var max_health: int = 1
var current_health: int = 1
var damage: int = 0
var attack_speed: float = 1.0
var attack_range: float = 0.0
var _is_dead: bool = false
var _target_position: Vector2
var _is_moving: bool = false
var _attack_target: UnitBase = null
var _attack_cooldown: float = 0.0
var _enemies_in_range: Array[UnitBase] = []
var _attack_area: Area2D = null

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("units")
	_target_position = position
	_load_stats()
	_setup_attack_area()
	EventBus.unit_died.connect(_on_unit_died)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _is_moving:
		_process_movement()
	elif _attack_target != null:
		_process_attacking(delta)
	else:
		_try_acquire_target()


func move_to(target: Vector2) -> void:
	if _is_dead:
		return
	# Prevent jitter when clicking current position
	if position.distance_to(target) <= ARRIVAL_THRESHOLD:
		return
	_target_position = target
	_is_moving = true
	_attack_target = null
	attack_stopped.emit()


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	_is_moving = false
	velocity = Vector2.ZERO
	_attack_target = null
	_enemies_in_range.clear()
	if _attack_area != null:
		var shape_node := _attack_area.get_child(0) as CollisionShape2D
		if shape_node:
			shape_node.set_deferred("disabled", true)
	remove_from_group("units")
	EventBus.unit_died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _load_stats() -> void:
	var file := FileAccess.open("res://data/unit_stats.json", FileAccess.READ)
	if not file:
		push_warning("UnitBase: Could not open unit_stats.json")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning("UnitBase: Failed to parse unit_stats.json: %s" % json.get_error_message())
		return
	var stats: Dictionary = json.data
	if not stats.has(unit_type):
		push_warning("UnitBase: No stats found for unit_type '%s'" % unit_type)
		return
	var unit_stats: Dictionary = stats[unit_type]
	max_health = unit_stats.get("health", 50)
	current_health = max_health
	damage = unit_stats.get("damage", 10)
	attack_speed = unit_stats.get("attack_speed", 1.0)
	move_speed = unit_stats.get("move_speed", move_speed)
	attack_range = unit_stats.get("attack_range", 0.0)
	health_changed.emit(current_health, max_health)


func _setup_attack_area() -> void:
	if attack_range <= 0.0:
		return
	_attack_area = Area2D.new()
	_attack_area.name = "AttackRange"
	_attack_area.collision_layer = 2
	_attack_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = attack_range
	shape.shape = circle
	_attack_area.add_child(shape)
	add_child(_attack_area)
	_attack_area.body_entered.connect(_on_body_entered_attack_range)
	_attack_area.body_exited.connect(_on_body_exited_attack_range)


func _process_movement() -> void:
	var distance := position.distance_to(_target_position)

	if distance <= ARRIVAL_THRESHOLD:
		_is_moving = false
		velocity = Vector2.ZERO
		_update_animation()
		return

	var direction := (_target_position - position).normalized()
	velocity = direction * move_speed

	_update_animation(direction)

	move_and_slide()


func _process_attacking(delta: float) -> void:
	if not _is_valid_target(_attack_target):
		_attack_target = null
		attack_stopped.emit()
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


func _is_valid_target(target: UnitBase) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if target._is_dead:
		return false
	if target.team_id == team_id:
		return false
	return true


func _perform_attack() -> void:
	if not _is_valid_target(_attack_target):
		return
	_attack_target.take_damage(damage)
	EventBus.unit_attacked.emit(self, _attack_target, damage)


func _get_attack_interval() -> float:
	if attack_speed <= 0.0:
		return 1.0
	return 1.0 / attack_speed


func _on_body_entered_attack_range(body: Node2D) -> void:
	if body is UnitBase and body != self and body.team_id != team_id and not body._is_dead:
		_enemies_in_range.append(body)


func _on_body_exited_attack_range(body: Node2D) -> void:
	if body is UnitBase:
		_enemies_in_range.erase(body)
		if _attack_target == body:
			_attack_target = null
			attack_stopped.emit()


func _on_unit_died(unit: Node) -> void:
	if unit is UnitBase:
		_enemies_in_range.erase(unit)
		if _attack_target == unit:
			_attack_target = null
			attack_stopped.emit()


func _update_animation(direction: Vector2 = Vector2.ZERO) -> void:
	if _is_moving:
		if abs(direction.x) > 0.1:
			_sprite.flip_h = direction.x < 0
		if _sprite.animation != "walk":
			_sprite.play("walk")
	else:
		if _sprite.animation != "idle":
			_sprite.play("idle")
