class_name UnitBase extends CharacterBody2D
## Base class for all game units.
## Provides common functionality like movement and group membership.

## Movement speed in pixels per second
@export var move_speed: float = 150.0


func _ready() -> void:
	add_to_group("units")


func _physics_process(_delta: float) -> void:
	pass  # Movement will be added in SPI-1349
