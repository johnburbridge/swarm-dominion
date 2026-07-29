extends GutTest
## Tests for the greybox arena (SPI-1444) — the playable map definition that
## main.tscn loads.
##
## Deliberately separate from test_arena.json, which stays a small fixed parse
## fixture for test_map_definition.gd. Pinning entity counts on the real game
## map would break that fixture every time the layout is tuned for balance.
##
## The symmetry checks here are drift guards, not descriptions: Appendix A
## principle 1 makes symmetry a hard requirement of every competitive map, and
## an asymmetric map is a balance defect that is invisible by inspection once
## the layout grows past a handful of entities.

const GREYBOX_PATH: String = "res://data/map_definitions/greybox_arena.json"
const MIRRORED_CATEGORIES: Array[String] = [
	"spawn_points", "biomass_nodes", "control_points", "units", "obstacles"
]


func _def() -> MapDefinition:
	return MapDefinition.from_file(GREYBOX_PATH)


func _center_x(def: MapDefinition) -> float:
	return def.bounds.position.x + def.bounds.size.x / 2.0


## Reflects a point across the vertical axis through `center_x`. This map uses
## mirror symmetry about the vertical centre line; a rotationally symmetric map
## would need a different reflection here.
func _mirror(pos: Vector2, center_x: float) -> Vector2:
	return Vector2(2.0 * center_x - pos.x, pos.y)


## A whole-pixel key, so mirrored and original layouts compare as multisets
## without float-equality trouble. Rounding is the tolerance: a position off by
## a pixel is symmetric enough, one off by ten is not.
func _key(pos: Vector2) -> String:
	return "%d,%d" % [roundi(pos.x), roundi(pos.y)]


func _keys(entries: Array, center_x: float, mirrored: bool) -> Array:
	var keys: Array = []
	for entry in entries:
		var pos: Vector2 = entry["position"]
		keys.append(_key(_mirror(pos, center_x) if mirrored else pos))
	keys.sort()
	return keys


func _opposing(team_id: int) -> int:
	return 2 if team_id == 1 else 1


func test_definition_loads() -> void:
	assert_not_null(_def(), "greybox arena parses")


func test_bounds_match_the_world_the_player_actually_sees() -> void:
	# minimap.gd projects world -> minimap through MAP_ORIGIN/MAP_SIZE, and
	# main.tscn's background sprite covers exactly that rect. A map whose bounds
	# are a sub-rect of it clamps the camera tighter than the visible world,
	# which is the bug test_arena.json has today (1920x1080 at the origin).
	var def := _def()
	assert_eq(def.bounds.position, Minimap.MAP_ORIGIN, "origin matches the minimap world origin")
	assert_eq(def.bounds.size, Minimap.MAP_SIZE, "size matches the minimap world size")


func test_layout_is_mirror_symmetric_about_the_vertical_centre() -> void:
	var def := _def()
	var center_x := _center_x(def)
	for category in MIRRORED_CATEGORIES:
		var entries: Array = def.get(category)
		assert_false(entries.is_empty(), "%s is populated" % category)
		assert_eq(
			_keys(entries, center_x, true),
			_keys(entries, center_x, false),
			"%s mirrors about x=%d" % [category, roundi(center_x)]
		)


func test_mirroring_swaps_the_two_teams() -> void:
	# Geometry alone is not enough: a layout can be perfectly symmetric while
	# handing both bases to the same team. Reflecting team 1's entities must
	# land exactly on team 2's.
	var def := _def()
	var center_x := _center_x(def)
	for category in ["spawn_points", "units"]:
		var entries: Array = def.get(category)
		var original: Array = []
		var reflected: Array = []
		for entry in entries:
			var team: int = entry["team_id"]
			var pos: Vector2 = entry["position"]
			original.append("t%d@%s" % [team, _key(pos)])
			reflected.append("t%d@%s" % [_opposing(team), _key(_mirror(pos, center_x))])
		original.sort()
		reflected.sort()
		assert_eq(reflected, original, "%s reflect onto the opposing team" % category)


func test_both_teams_get_a_spawn() -> void:
	var def := _def()
	var teams: Array = []
	for spawn in def.spawn_points:
		teams.append(spawn["team_id"])
	teams.sort()
	assert_eq(teams, [1, 2], "exactly one spawn each for teams 1 and 2")


func test_control_points_follow_the_appendix_a_distribution() -> void:
	# PRD 2.6 / Appendix A: one central high-value point, 2-4 peripheral points
	# worth less. The count band is the milestone's own acceptance criterion.
	var def := _def()
	assert_between(def.control_points.size(), 3, 5, "3-5 control points")

	var central: Array = []
	var peripheral: Array = []
	for cp in def.control_points:
		if int(cp["vp_weight"]) > 1:
			central.append(cp)
		else:
			peripheral.append(cp)

	assert_eq(central.size(), 1, "exactly one high-value point")
	assert_true(peripheral.size() >= 2, "at least two peripheral points")

	var map_center := def.bounds.position + def.bounds.size / 2.0
	assert_eq(central[0]["position"], map_center, "the high-value point sits at map centre")
	for cp in peripheral:
		assert_gt(
			float(central[0]["capture_radius"]),
			float(cp["capture_radius"]),
			"central zone is larger than peripheral zone at %s" % _key(cp["position"])
		)


func test_every_entity_sits_inside_the_map_bounds() -> void:
	var def := _def()
	for category in MIRRORED_CATEGORIES:
		for entry in def.get(category):
			var pos: Vector2 = entry["position"]
			assert_true(
				def.bounds.has_point(pos),
				"%s entity at %s is inside bounds" % [category, _key(pos)]
			)


func test_obstacles_are_present_for_pathfinding_work() -> void:
	# SPI-1450 bakes a NavigationPolygon from these. A greybox with no obstacle
	# cannot demonstrate any of that story's acceptance criteria.
	var def := _def()
	assert_true(def.obstacles.size() >= 2, "at least one symmetric obstacle pair")
	for obstacle in def.obstacles:
		var size: Vector2 = obstacle["size"]
		assert_gt(size.x, 0.0, "obstacle has positive width")
		assert_gt(size.y, 0.0, "obstacle has positive height")
