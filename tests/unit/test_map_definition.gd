extends GutTest
## Tests for MapDefinition parse/validate layer (SPI-1443).


func _valid_dict() -> Dictionary:
	return {
		"name": "Sample",
		"bounds": {"x": 0, "y": 0, "width": 1920, "height": 1080},
		"spawn_points": [{"team_id": 1, "position": [760, 400]}],
		"biomass_nodes": [{"position": [500, 400]}, {"position": [950, 300]}],
		"control_points":
		[{"id": "center", "position": [960, 540], "capture_radius": 96, "vp_weight": 3}],
		"units": [{"type": "drone", "team_id": 2, "position": [1100, 480]}],
	}


func test_from_dict_parses_scalar_and_bounds() -> void:
	var def := MapDefinition.from_dict(_valid_dict())
	assert_eq(def.map_name, "Sample", "reads name")
	assert_eq(def.bounds, Rect2(0, 0, 1920, 1080), "reads bounds as Rect2")


func test_from_dict_parses_entry_counts() -> void:
	var def := MapDefinition.from_dict(_valid_dict())
	assert_eq(def.spawn_points.size(), 1, "one spawn point")
	assert_eq(def.biomass_nodes.size(), 2, "two biomass nodes")
	assert_eq(def.control_points.size(), 1, "one control point")
	assert_eq(def.units.size(), 1, "one unit")


func test_spawn_point_has_team_and_vector_position() -> void:
	var def := MapDefinition.from_dict(_valid_dict())
	assert_eq(def.spawn_points[0]["team_id"], 1, "spawn team_id")
	assert_eq(def.spawn_points[0]["position"], Vector2(760, 400), "spawn position is Vector2")


func test_control_point_reads_radius_and_weight() -> void:
	var def := MapDefinition.from_dict(_valid_dict())
	var cp: Dictionary = def.control_points[0]
	assert_eq(cp["capture_radius"], 96.0, "capture_radius")
	assert_eq(cp["vp_weight"], 3, "vp_weight")
	assert_eq(cp["position"], Vector2(960, 540), "cp position is Vector2")


func test_control_point_defaults_when_optional_fields_missing() -> void:
	var def := MapDefinition.from_dict({"control_points": [{"position": [10, 20]}]})
	var cp: Dictionary = def.control_points[0]
	assert_eq(cp["capture_radius"], MapDefinition.DEFAULT_CAPTURE_RADIUS, "default radius")
	assert_eq(cp["vp_weight"], MapDefinition.DEFAULT_VP_WEIGHT, "default weight")


func test_missing_top_level_arrays_default_to_empty() -> void:
	var def := MapDefinition.from_dict({"name": "Bare"})
	assert_eq(def.spawn_points.size(), 0, "no spawn points")
	assert_eq(def.biomass_nodes.size(), 0, "no biomass nodes")
	assert_eq(def.control_points.size(), 0, "no control points")
	assert_eq(def.units.size(), 0, "no units")
	assert_eq(def.bounds, Rect2(), "default bounds")


func test_malformed_entry_is_skipped_siblings_retained() -> void:
	var def := (
		MapDefinition
		. from_dict(
			{
				"biomass_nodes":
				[{"position": [500, 400]}, {"no_position": true}, {"position": [1, 2]}],
			}
		)
	)
	assert_eq(def.biomass_nodes.size(), 2, "bad entry skipped, two valid retained")
	assert_engine_error(1, "expected warning for the skipped malformed entry")


func test_from_file_parses_sample_end_to_end() -> void:
	var def := MapDefinition.from_file("res://data/map_definitions/test_arena.json")
	assert_not_null(def, "sample parses")
	assert_eq(def.spawn_points.size(), 2, "two spawn points")
	assert_eq(def.biomass_nodes.size(), 4, "four biomass nodes")
	assert_eq(def.control_points.size(), 1, "one control point")
	assert_eq(def.units.size(), 7, "seven test units")


func test_from_file_missing_returns_null() -> void:
	var def := MapDefinition.from_file("res://data/map_definitions/does_not_exist.json")
	assert_null(def, "missing file returns null")
	assert_engine_error(1, "expected warning for the missing file")
