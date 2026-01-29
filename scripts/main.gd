extends Node2D
## Main scene controller.
## This is the entry point for the game.

const DroneScene = preload("res://scenes/units/drone.tscn")

var _player_drone: UnitBase
var _enemy_drone: UnitBase

@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	print("Swarm Dominion initialized")
	_spawn_test_units()


func _process(_delta: float) -> void:
	if _player_drone and is_instance_valid(_player_drone):
		_camera.global_position = _player_drone.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("command"):
		var click_position = get_global_mouse_position()
		if _player_drone and is_instance_valid(_player_drone):
			_player_drone.move_to(click_position)
			print("Move command to ", click_position)


func _spawn_test_units() -> void:
	_player_drone = DroneScene.instantiate()
	_player_drone.team_id = 1
	_player_drone.position = Vector2(760, 540)
	_player_drone.modulate = Color(0.7, 1.0, 0.7)
	add_child(_player_drone)
	print("Spawned player drone at ", _player_drone.position)

	_enemy_drone = DroneScene.instantiate()
	_enemy_drone.team_id = 2
	_enemy_drone.position = Vector2(1160, 540)
	_enemy_drone.modulate = Color(1.0, 0.7, 0.7)
	add_child(_enemy_drone)
	print("Spawned enemy drone at ", _enemy_drone.position)
