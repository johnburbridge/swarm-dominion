class_name Minimap extends Control
## Renders a minimap showing unit positions and camera viewport.
## Supports click-to-navigate.

const MAP_SIZE: Vector2 = Vector2(3840, 2160)
const MINIMAP_SIZE: Vector2 = Vector2(200, 112)
const VIEWPORT_SIZE: Vector2 = Vector2(1920, 1080)
const DOT_RADIUS: float = 3.0
const PLAYER_TEAM_ID: int = 1
const BG_COLOR: Color = Color(0.1, 0.1, 0.12, 0.85)
const BORDER_COLOR: Color = Color(0.6, 0.6, 0.6, 0.9)
const FRIENDLY_COLOR: Color = Color(0.2, 0.9, 0.2)
const ENEMY_COLOR: Color = Color(0.9, 0.2, 0.2)
const VIEWPORT_RECT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)

var _camera: Camera2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_camera(camera: Camera2D) -> void:
	_camera = camera


func world_to_minimap(world_pos: Vector2) -> Vector2:
	return Vector2(
		world_pos.x / MAP_SIZE.x * MINIMAP_SIZE.x,
		world_pos.y / MAP_SIZE.y * MINIMAP_SIZE.y,
	)


func minimap_to_world(minimap_pos: Vector2) -> Vector2:
	return Vector2(
		minimap_pos.x / MINIMAP_SIZE.x * MAP_SIZE.x,
		minimap_pos.y / MINIMAP_SIZE.y * MAP_SIZE.y,
	)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), BG_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), BORDER_COLOR, false, 1.0)

	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as UnitBase
		if unit == null:
			continue
		var dot_pos := world_to_minimap(unit.global_position)
		var dot_color: Color = FRIENDLY_COLOR if unit.team_id == PLAYER_TEAM_ID else ENEMY_COLOR
		draw_circle(dot_pos, DOT_RADIUS, dot_color)

	if _camera != null and is_instance_valid(_camera):
		var cam_pos := _camera.global_position
		var half_viewport := VIEWPORT_SIZE / 2.0
		var top_left := world_to_minimap(cam_pos - half_viewport)
		var bottom_right := world_to_minimap(cam_pos + half_viewport)
		var rect := Rect2(top_left, bottom_right - top_left)
		draw_rect(rect, VIEWPORT_RECT_COLOR, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb_event: InputEventMouseButton = event as InputEventMouseButton
		if mb_event.button_index == MOUSE_BUTTON_LEFT and mb_event.pressed:
			var local_pos: Vector2 = mb_event.position
			var world_pos := minimap_to_world(local_pos)
			if _camera != null and is_instance_valid(_camera):
				_camera.global_position = world_pos
			accept_event()
