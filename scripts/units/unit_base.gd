class_name UnitBase extends CharacterBody2D
## Base class for all game units.
## Provides common functionality like movement and group membership.

signal health_changed(current_health: int, max_health: int)

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
var _is_dead: bool = false
var _target_position: Vector2
var _is_moving: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("units")
	_target_position = position
	_load_stats()


func _physics_process(_delta: float) -> void:
	if _is_dead:
		return
	if not _is_moving:
		return

	var distance = position.distance_to(_target_position)

	if distance <= ARRIVAL_THRESHOLD:
		_is_moving = false
		velocity = Vector2.ZERO
		_update_animation()
		return

	var direction = (_target_position - position).normalized()
	velocity = direction * move_speed

	_update_animation(direction)

	move_and_slide()


func move_to(target: Vector2) -> void:
	if _is_dead:
		return
	# Prevent jitter when clicking current position
	if position.distance_to(target) <= ARRIVAL_THRESHOLD:
		return
	_target_position = target
	_is_moving = true


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


func _update_animation(direction: Vector2 = Vector2.ZERO) -> void:
	if _is_moving:
		if abs(direction.x) > 0.1:
			_sprite.flip_h = direction.x < 0
		if _sprite.animation != "walk":
			_sprite.play("walk")
	else:
		if _sprite.animation != "idle":
			_sprite.play("idle")
