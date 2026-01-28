extends Node2D
## Main scene controller.
## This is the entry point for the game.

const DroneScene = preload("res://scenes/units/drone.tscn")

var _test_drone: UnitBase


func _ready() -> void:
	print("Swarm Dominion initialized")
	_spawn_test_unit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("command"):
		var click_position = get_global_mouse_position()
		if _test_drone:
			_test_drone.move_to(click_position)
			print("Move command to ", click_position)


func _spawn_test_unit() -> void:
	_test_drone = DroneScene.instantiate()
	_test_drone.position = Vector2(960, 540)
	add_child(_test_drone)
	print("Spawned test drone at ", _test_drone.position)
