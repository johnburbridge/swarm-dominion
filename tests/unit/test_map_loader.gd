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
	# Layers 1-3 are units / unit attack range / biomass nodes, named in
	# project.godot's [layer_names]. The obstacle layer was 2 until SPI-1444's
	# review found it double-booked with unit_base.gd's attack-detection Area2D,
	# which made every wall a valid auto-attack target. Nothing about "pick the
	# next free layer" is self-checking, so pin the disjointness.
	assert_eq(MapLoader.OBSTACLE_LAYER & 0b0111, 0, "obstacle layer is disjoint from layers 1-3")


func test_units_collide_with_obstacles_as_well_as_each_other() -> void:
	# A wall on a layer no unit masks is scenery, not an obstacle. Both unit
	# scenes must mask the unit layer (1) and MapLoader.OBSTACLE_LAYER.
	for path in ["res://scenes/units/drone.tscn", "res://scenes/units/mother.tscn"]:
		var unit := (load(path) as PackedScene).instantiate() as CharacterBody2D
		autofree(unit)
		assert_eq(unit.collision_layer, 1, "%s is on the unit layer" % path)
		assert_eq(unit.collision_mask & 1, 1, "%s collides with other units" % path)
		assert_eq(
			unit.collision_mask & MapLoader.OBSTACLE_LAYER,
			MapLoader.OBSTACLE_LAYER,
			"%s collides with obstacles" % path
		)
		# MOTION_MODE_FLOATING. The platformer default classifies a wall's top
		# face as floor and its bottom as ceiling, which made mirrored diagonal
		# approaches to a symmetric pair of walls diverge by ~3px.
		assert_eq(
			unit.motion_mode,
			CharacterBody2D.MOTION_MODE_FLOATING,
			"%s uses floating motion, not the grounded platformer default" % path
		)
