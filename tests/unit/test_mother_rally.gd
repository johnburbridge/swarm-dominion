extends GutTest
## Tests for Mother rally points (SPI-1424): the default effective rally sits just
## below the Mother; an explicit rally is recorded and returned; spawned drones walk
## to the effective rally; the marker is visible only when the Mother is selected AND
## has an explicit rally (deselect retains the point).

var _mother_scene: PackedScene


func before_all() -> void:
	_mother_scene = load("res://scenes/units/mother.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _create_mother(tid: int, pos: Vector2) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = pos
	add_child_autofree(mother)
	return mother


func test_no_rally_by_default() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	assert_false(mother.has_rally(), "a fresh Mother should have no explicit rally")


func test_effective_rally_defaults_below_mother() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	assert_eq(
		mother.get_effective_rally(),
		Vector2(400, 300) + Vector2(0, 96),
		"with no rally set, effective rally is just below the Mother"
	)


func test_set_rally_point_records_point() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	assert_true(mother.has_rally(), "has_rally should be true after set_rally_point")
	assert_eq(mother.get_rally_point(), Vector2(700, 500), "get_rally_point returns the set point")
	assert_eq(
		mother.get_effective_rally(), Vector2(700, 500), "effective rally is the explicit point"
	)


func test_spawned_drone_moves_to_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	mother.set_rally_point(Vector2(900, 700))
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_not_null(drone, "spawn should succeed")
	assert_eq(
		drone._target_position, Vector2(900, 700), "spawned drone should target the rally point"
	)
	assert_eq(drone._state, UnitBase.UnitState.MOVING, "spawned drone should be moving to rally")


func test_spawned_drone_moves_to_default_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_not_null(drone, "spawn should succeed")
	assert_eq(
		drone._target_position,
		Vector2(400, 300) + Vector2(0, 96),
		"with no rally, spawned drone should target the default just below the Mother"
	)


func test_marker_hidden_when_unselected() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	assert_false(
		mother._rally_marker.visible, "marker should be hidden while the Mother is unselected"
	)


func test_marker_visible_when_selected_with_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	mother.set_selected(true)
	assert_true(
		mother._rally_marker.visible, "marker should be visible when selected and rally set"
	)


func test_marker_hidden_when_selected_without_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_selected(true)
	assert_false(
		mother._rally_marker.visible, "marker should stay hidden when selected with no rally set"
	)


func test_deselect_hides_marker_but_retains_rally() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	mother.set_rally_point(Vector2(700, 500))
	mother.set_selected(true)
	mother.set_selected(false)
	assert_false(mother._rally_marker.visible, "marker should hide after deselect")
	assert_true(mother.has_rally(), "rally should be retained after deselect")
	assert_eq(
		mother.get_rally_point(), Vector2(700, 500), "rally point should be retained after deselect"
	)
