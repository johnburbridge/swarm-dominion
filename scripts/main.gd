extends Node2D
## Main scene controller.
## This is the entry point for the game.

const DroneScene = preload("res://scenes/units/drone.tscn")


func _ready() -> void:
	print("Swarm Dominion initialized")
	_spawn_test_unit()


func _process(_delta: float) -> void:
	pass


func _spawn_test_unit() -> void:
	var drone = DroneScene.instantiate()
	drone.position = Vector2(960, 540)  # Center of 1920x1080
	add_child(drone)
	print("Spawned test drone at ", drone.position)
