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
