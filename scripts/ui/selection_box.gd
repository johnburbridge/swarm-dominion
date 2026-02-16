class_name SelectionBox extends Control
## Draws the drag-selection rectangle overlay in screen space.

const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const FILL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
const BORDER_WIDTH: float = 1.0

var _start_pos: Vector2 = Vector2.ZERO
var _end_pos: Vector2 = Vector2.ZERO
var _is_active: bool = false


func begin(start_position: Vector2) -> void:
	_start_pos = start_position
	_end_pos = start_position
	_is_active = true
	queue_redraw()


func update_end(end_position: Vector2) -> void:
	_end_pos = end_position
	queue_redraw()


func finish() -> Rect2:
	_is_active = false
	var rect := get_rect2()
	queue_redraw()
	return rect


func get_rect2() -> Rect2:
	var top_left := Vector2(minf(_start_pos.x, _end_pos.x), minf(_start_pos.y, _end_pos.y))
	var bottom_right := Vector2(maxf(_start_pos.x, _end_pos.x), maxf(_start_pos.y, _end_pos.y))
	return Rect2(top_left, bottom_right - top_left)


func _draw() -> void:
	if not _is_active:
		return
	var rect := get_rect2()
	draw_rect(rect, FILL_COLOR, true)
	draw_rect(rect, BORDER_COLOR, false, BORDER_WIDTH)
