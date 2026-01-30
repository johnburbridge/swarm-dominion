extends Node2D
## Main scene controller.
## This is the entry point for the game.

const DroneScene = preload("res://scenes/units/drone.tscn")
const PLAYER_TEAM_ID: int = 1

@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	print("Swarm Dominion initialized")
	_spawn_test_units()


func _process(_delta: float) -> void:
	var selected := SelectionManager.get_selected_units()
	if selected.size() > 0 and is_instance_valid(selected[0]):
		_camera.global_position = selected[0].global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		_handle_select()
	elif event.is_action_pressed("command"):
		_handle_command()


func _handle_select() -> void:
	var click_pos := get_global_mouse_position()
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = click_pos
	params.collision_mask = 1
	var results := space_state.intersect_point(params)

	for result in results:
		var collider = result["collider"]
		if collider is UnitBase and collider.team_id == PLAYER_TEAM_ID:
			SelectionManager.select_unit(collider)
			return

	SelectionManager.deselect_all()


func _handle_command() -> void:
	var click_pos := get_global_mouse_position()
	var selected := SelectionManager.get_selected_units()
	for unit in selected:
		if is_instance_valid(unit):
			unit.move_to(click_pos)


func _spawn_test_units() -> void:
	var player_drone := DroneScene.instantiate()
	player_drone.team_id = 1
	player_drone.position = Vector2(760, 540)
	player_drone.modulate = Color(0.7, 1.0, 0.7)
	add_child(player_drone)
	print("Spawned player drone at ", player_drone.position)

	var enemy_drone := DroneScene.instantiate()
	enemy_drone.team_id = 2
	enemy_drone.position = Vector2(1160, 540)
	enemy_drone.modulate = Color(1.0, 0.7, 0.7)
	add_child(enemy_drone)
	print("Spawned enemy drone at ", enemy_drone.position)
