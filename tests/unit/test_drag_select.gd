extends GutTest
## Tests for SelectionBox and drag-selection behavior (SPI-1370).

var _selection_box: SelectionBox
var _drone_scene: PackedScene
var _unit_a: UnitBase
var _unit_b: UnitBase
var _enemy: UnitBase


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	SelectionManager.deselect_all()
	_selection_box = SelectionBox.new()
	add_child_autofree(_selection_box)
	await get_tree().process_frame


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
