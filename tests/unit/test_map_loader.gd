extends GutTest
## Tests for MapLoader instantiation layer (SPI-1443).

var _parent: Node2D


func before_each() -> void:
	_parent = Node2D.new()
	add_child_autofree(_parent)


func _def(overrides: Dictionary) -> MapDefinition:
	var base := {
		"spawn_points": [{"team_id": 1, "position": [760, 400]}],
		"biomass_nodes": [{"position": [500, 400]}, {"position": [950, 300]}],
		"control_points":
		[{"id": "center", "position": [960, 540], "capture_radius": 96, "vp_weight": 3}],
		"units": [{"type": "drone", "team_id": 2, "position": [1100, 480]}],
	}
	base.merge(overrides, true)
	return MapDefinition.from_dict(base)


func test_populate_spawns_biomass_nodes() -> void:
	var loaded := MapLoader.populate(_def({}), _parent)
	assert_eq(loaded["biomass_nodes"].size(), 2, "two biomass nodes spawned")
	assert_true(loaded["biomass_nodes"][0] is BiomassNode, "spawned node is a BiomassNode")
	assert_eq(loaded["biomass_nodes"][0].get_parent(), _parent, "added under parent")


func test_populate_spawns_a_mother_per_spawn_point() -> void:
	var loaded := MapLoader.populate(_def({}), _parent)
	assert_eq(loaded["mothers"].size(), 1, "one mother")
	var mother: MotherUnit = loaded["mothers"][0]
	assert_eq(mother.team_id, 1, "mother team_id from spawn point")
	assert_eq(mother.position, Vector2(760, 400), "mother position from spawn point")


func test_populate_builds_control_point_placeholder() -> void:
	var loaded := MapLoader.populate(_def({}), _parent)
	assert_eq(loaded["control_points"].size(), 1, "one control point")
	var cp: Node = loaded["control_points"][0]
	assert_true(cp.is_in_group(MapLoader.CONTROL_POINT_GROUP), "in control_points group")
	assert_eq(cp.get_meta("vp_weight"), 3, "vp_weight in metadata")
	var area := cp.get_node("CaptureZone") as Area2D
	assert_not_null(area, "has a CaptureZone Area2D")
	var shape := area.get_child(0) as CollisionShape2D
	assert_eq((shape.shape as CircleShape2D).radius, 96.0, "capture radius on the shape")


func test_populate_spawns_optional_units() -> void:
	var loaded := MapLoader.populate(_def({}), _parent)
	assert_eq(loaded["units"].size(), 1, "one unit spawned")
	assert_eq(loaded["units"][0].team_id, 2, "unit team_id")


func test_populate_skips_unknown_unit_type() -> void:
	var loaded := MapLoader.populate(
		_def({"units": [{"type": "dragon", "team_id": 1, "position": [0, 0]}]}), _parent
	)
	assert_eq(loaded["units"].size(), 0, "unknown type skipped")
	assert_engine_error(1, "expected warning for unknown unit type")


func test_populate_null_definition_returns_empty() -> void:
	var loaded := MapLoader.populate(null, _parent)
	assert_eq(loaded["mothers"].size(), 0, "no mothers")
	assert_eq(loaded["biomass_nodes"].size(), 0, "no biomass nodes")
	assert_engine_error(1, "expected warning for null definition")


func test_populate_builds_obstacle_bodies() -> void:
	var loaded := MapLoader.populate(
		_def({"obstacles": [{"position": [560, 540], "size": [80, 400]}]}), _parent
	)
	assert_eq(loaded["obstacles"].size(), 1, "one obstacle")
	var body: StaticBody2D = loaded["obstacles"][0]
	assert_eq(body.position, Vector2(560, 540), "obstacle position")
	assert_true(body.is_in_group(MapLoader.OBSTACLE_GROUP), "in obstacles group")
	var shape := body.get_child(0) as CollisionShape2D
	assert_eq((shape.shape as RectangleShape2D).size, Vector2(80, 400), "rect size from the data")


func test_obstacle_blocks_units_but_is_not_pickable_as_one() -> void:
	# Obstacles sit on their own layer so click-to-select point queries against
	# the unit layer never return them, while units still physically collide.
	var loaded := MapLoader.populate(
		_def({"obstacles": [{"position": [0, 0], "size": [10, 10]}]}), _parent
	)
	var body: StaticBody2D = loaded["obstacles"][0]
	assert_eq(body.collision_layer, MapLoader.OBSTACLE_LAYER, "on the obstacle layer")
	# Literal 1 rather than a symbol: main.gd declares UNIT_COLLISION_MASK but has
	# no class_name, so it is not referenceable from here.
	assert_eq(body.collision_layer & 1, 0, "not on the unit layer main.gd point-queries")
	assert_eq(body.collision_mask, 0, "obstacles are static and detect nothing themselves")
