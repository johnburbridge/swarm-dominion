extends Node2D
## Main scene controller.
## This is the entry point for the game.

const DroneScene = preload("res://scenes/units/drone.tscn")
const PLAYER_TEAM_ID: int = 1
const DRAG_THRESHOLD: float = 4.0

var _is_select_pressed: bool = false
var _select_press_position: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _attack_move_pending: bool = false

@onready var _camera: Camera2D = $Camera2D
@onready var _selection_box: SelectionBox = $UI/SelectionBox


func _ready() -> void:
	print("Swarm Dominion initialized")
	_spawn_test_units()


func _process(_delta: float) -> void:
	var selected := SelectionManager.get_selected_units()
	if selected.size() > 0 and is_instance_valid(selected[0]):
		_camera.global_position = selected[0].global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_select(event.position)
		else:
			_end_select(event.position)
	elif event is InputEventMouseMotion and _is_select_pressed:
		_update_drag(event.position)
	elif event.is_action_pressed("attack_move"):
		_attack_move_pending = true
	elif event.is_action_pressed("command"):
		_handle_command()


func _begin_select(screen_pos: Vector2) -> void:
	_is_select_pressed = true
	_select_press_position = screen_pos
	_is_dragging = false


func _update_drag(screen_pos: Vector2) -> void:
	if not _is_dragging:
		if _select_press_position.distance_to(screen_pos) >= DRAG_THRESHOLD:
			_is_dragging = true
			_selection_box.begin(_select_press_position)
	if _is_dragging:
		_selection_box.update_end(screen_pos)


func _end_select(_screen_pos: Vector2) -> void:
	if not _is_select_pressed:
		return
	_is_select_pressed = false

	if _is_dragging:
		_finish_drag_select()
	else:
		_handle_click_select()

	_is_dragging = false


func _finish_drag_select() -> void:
	var rect := _selection_box.finish()
	var selected: Array[UnitBase] = []
	var canvas_transform := get_viewport().get_canvas_transform()
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as UnitBase
		if unit == null or unit.team_id != PLAYER_TEAM_ID:
			continue
		var unit_screen_pos := canvas_transform * unit.global_position
		if rect.has_point(unit_screen_pos):
			selected.append(unit)
	SelectionManager.select_units(selected)


func _handle_click_select() -> void:
	if _attack_move_pending:
		_attack_move_pending = false
		_issue_attack_move()
		return
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


func _issue_attack_move() -> void:
	var click_pos := get_global_mouse_position()
	var selected := SelectionManager.get_selected_units()
	for unit in selected:
		if is_instance_valid(unit):
			unit.attack_move_to(click_pos)


func _handle_command() -> void:
	var click_pos := get_global_mouse_position()
	var selected := SelectionManager.get_selected_units()
	for unit in selected:
		if is_instance_valid(unit):
			unit.move_to(click_pos)


func _spawn_test_units() -> void:
	var player_positions: Array[Vector2] = [
		Vector2(700, 480),
		Vector2(760, 540),
		Vector2(820, 480),
		Vector2(760, 600),
	]
	for pos in player_positions:
		var drone := DroneScene.instantiate()
		drone.team_id = 1
		drone.position = pos
		drone.modulate = Color(0.7, 1.0, 0.7)
		add_child(drone)
	print("Spawned %d player drones" % player_positions.size())

	var enemy_positions: Array[Vector2] = [
		Vector2(1100, 480),
		Vector2(1160, 540),
		Vector2(1220, 480),
	]
	for pos in enemy_positions:
		var drone := DroneScene.instantiate()
		drone.team_id = 2
		drone.position = pos
		drone.modulate = Color(1.0, 0.7, 0.7)
		add_child(drone)
	print("Spawned %d enemy drones" % enemy_positions.size())
