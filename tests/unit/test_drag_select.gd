extends GutTest
## Tests for SelectionBox and drag-selection behavior (SPI-1370).

var _selection_box: SelectionBox
var _drone_scene: PackedScene
var _saved_select_events: Array = []
var _unit_a: UnitBase
var _unit_b: UnitBase
var _enemy: UnitBase


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	SelectionManager.deselect_all()
	# InputMap is global; snapshot rather than assuming the shipped binding, so a
	# future rebind of `select` is not silently rewritten to left-button by these tests.
	_saved_select_events = InputMap.action_get_events("select").duplicate()
	_selection_box = SelectionBox.new()
	add_child_autofree(_selection_box)
	await get_tree().process_frame


func after_each() -> void:
	InputMap.action_erase_events("select")
	for event in _saved_select_events:
		InputMap.action_add_event("select", event)


func _make_unit(team: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = team
	unit.position = pos
	add_child_autofree(unit)
	return unit


# --- SelectionBox unit tests ---


func test_selection_box_inactive_by_default() -> void:
	assert_false(_selection_box._is_active, "should not be active on creation")


func test_selection_box_rect_normalizes_coordinates() -> void:
	_selection_box.begin(Vector2(200, 300))
	_selection_box.update_end(Vector2(100, 150))
	var rect := _selection_box.get_rect2()
	assert_eq(rect.position, Vector2(100, 150), "top-left should be normalized")
	assert_eq(rect.size, Vector2(100, 150), "size should be positive")


func test_selection_box_finish_returns_rect_and_deactivates() -> void:
	_selection_box.begin(Vector2(10, 20))
	_selection_box.update_end(Vector2(110, 120))
	var rect := _selection_box.finish()
	assert_eq(rect.position, Vector2(10, 20), "rect position should match")
	assert_eq(rect.size, Vector2(100, 100), "rect size should match")
	assert_false(_selection_box._is_active, "should be inactive after finish")


# --- Drag-select integration tests ---


func test_drag_select_multiple_friendly_units() -> void:
	_unit_a = _make_unit(1, Vector2(50, 50))
	_unit_b = _make_unit(1, Vector2(80, 80))
	await get_tree().process_frame

	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_a := canvas_transform * _unit_a.global_position
	var screen_b := canvas_transform * _unit_b.global_position

	var margin := Vector2(20, 20)
	var rect_min := Vector2(minf(screen_a.x, screen_b.x), minf(screen_a.y, screen_b.y)) - margin
	var rect_max := Vector2(maxf(screen_a.x, screen_b.x), maxf(screen_a.y, screen_b.y)) + margin
	var rect := Rect2(rect_min, rect_max - rect_min)

	var selected: Array[UnitBase] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as UnitBase
		if unit == null or unit.team_id != 1:
			continue
		var unit_screen_pos := canvas_transform * unit.global_position
		if rect.has_point(unit_screen_pos):
			selected.append(unit)
	SelectionManager.select_units(selected)

	var result := SelectionManager.get_selected_units()
	assert_eq(result.size(), 2, "should select both friendly units")


func test_drag_select_excludes_enemy_units() -> void:
	_unit_a = _make_unit(1, Vector2(50, 50))
	_enemy = _make_unit(2, Vector2(60, 60))
	await get_tree().process_frame

	var canvas_transform := get_viewport().get_canvas_transform()
	var rect := Rect2(Vector2.ZERO, Vector2(500, 500))

	var selected: Array[UnitBase] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as UnitBase
		if unit == null or unit.team_id != 1:
			continue
		var unit_screen_pos := canvas_transform * unit.global_position
		if rect.has_point(unit_screen_pos):
			selected.append(unit)
	SelectionManager.select_units(selected)

	var result := SelectionManager.get_selected_units()
	assert_eq(result.size(), 1, "should only select friendly unit")
	assert_eq(result[0], _unit_a, "selected unit should be the friendly one")


func test_drag_select_empty_area_deselects() -> void:
	_unit_a = _make_unit(1, Vector2(500, 500))
	await get_tree().process_frame
	SelectionManager.select_unit(_unit_a)
	assert_eq(SelectionManager.get_selected_units().size(), 1, "precondition: one selected")

	var rect := Rect2(Vector2(10, 10), Vector2(20, 20))
	var canvas_transform := get_viewport().get_canvas_transform()

	var selected: Array[UnitBase] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as UnitBase
		if unit == null or unit.team_id != 1:
			continue
		var unit_screen_pos := canvas_transform * unit.global_position
		if rect.has_point(unit_screen_pos):
			selected.append(unit)
	SelectionManager.select_units(selected)

	var result := SelectionManager.get_selected_units()
	assert_eq(result.size(), 0, "should deselect all when drag area is empty")


# --- select action routing (SPI-1458) ---


## Rebinds `select` to the middle mouse button for one test, so the assertion can only
## pass if main.gd reads the action rather than hardcoding MOUSE_BUTTON_LEFT.
## after_each restores whatever was bound before.
func _rebind_select_to_middle() -> void:
	InputMap.action_erase_events("select")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_MIDDLE
	ev.pressed = true
	InputMap.action_add_event("select", ev)


func _mouse_event(button: int, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = Vector2(100, 100)
	return ev


func test_select_action_drives_click_selection() -> void:
	# docs/CONTROLS.md credits the `select` action for click and drag selection, and
	# promises the Action column is what you would rebind. That is only true if main.gd
	# routes through the action instead of hardcoding the left button.
	var main := load("res://scenes/main/main.tscn").instantiate() as Node2D
	add_child_autofree(main)
	await get_tree().process_frame
	_rebind_select_to_middle()
	main._unhandled_input(_mouse_event(MOUSE_BUTTON_MIDDLE, true))
	assert_true(
		main._is_select_pressed,
		"selection should follow the `select` binding, not a hardcoded button"
	)


func test_press_then_release_completes_the_selection_gesture() -> void:
	var main := load("res://scenes/main/main.tscn").instantiate() as Node2D
	add_child_autofree(main)
	await get_tree().process_frame
	main._unhandled_input(_mouse_event(MOUSE_BUTTON_LEFT, true))
	assert_true(main._is_select_pressed, "precondition: press armed the selection")
	main._unhandled_input(_mouse_event(MOUSE_BUTTON_LEFT, false))
	assert_false(main._is_select_pressed, "release should end the selection gesture")
