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
##
## What these checks CANNOT see. Each was found by an adversarial blind-spot
## pass (.claude/skills/proving-guards-can-fail) and left open deliberately:
##
## * Mirror symmetry is checked about the vertical axis only. This layout also
##   mirrors about the horizontal centre line, but nothing asserts that, so the
##   layout could drift top-heavy and stay green.
## * Nothing checks entities for overlap, or that the map is traversable. An
##   obstacle sized to seal the two halves apart but still inside bounds
##   (80x2160) would pass. What IS guarded is the out-of-bounds variant.
## * Degenerate control points pass: capture_radius 0 (uncapturable) and
##   vp_weight 0 or negative both satisfy the distribution test.
## * PRD 2.6 makes capture *time* vary by strategic value. The data model has no
##   such field, so "central point is higher-value" is asserted through
##   capture_radius, which is a zone size and not the same thing.
## * The centre point's exact vp_weight is unpinned (the test only asks for
##   > 1) because nothing consumes vp_weight until M7 wires capture.
##
## Verified as CLOSED by mutation, so do not assume they are still free: a
## malformed obstacle size, both spawns stacked on the mirror axis, a mirrored
## pair with differing size/radius/weight/type, the map scene repointed at a
## different definition file, a symmetry-preserving cull of any category down to
## a token pair, a duplicated or blanked control-point id, and an obstacle whose
## extents leave the bounds while its anchor stays inside them.

const GREYBOX_PATH: String = "res://data/map_definitions/greybox_arena.json"
const MAIN_SCENE_PATH: String = "res://scenes/main/main.tscn"
const MIRRORED_CATEGORIES: Array[String] = [
	"spawn_points", "biomass_nodes", "control_points", "units", "obstacles"
]

## Fields that must be IDENTICAL between a mirrored pair. Position alone is not
## symmetry — verified by mutation: resizing one choke-point wall from 80x400 to
## 1600x40 left the whole file green while one team faced a pillar and the other
## a map-spanning wall. team_id is absent deliberately: it must swap, not match,
## which test_mirroring_swaps_the_two_teams covers.
const MIRRORED_ATTRIBUTES: Dictionary = {
	"obstacles": ["size"],
	"control_points": ["capture_radius", "vp_weight"],
	"units": ["type"],
}

## FLOORS against degeneracy, not tuned design targets. Every symmetry check in
## this file is satisfied by a mirrored pair, so culling a category down to two
## entities passes everything else green — verified by mutation, 6 biomass nodes
## to 2 and an 8-drone starting army to 2 both stayed green. These say only
## "enough entities that the map is still the map"; the real counts belong to
## balance playtesting and must stay free to move above these numbers.
## control_points is absent deliberately: its 3-5 band is an acceptance
## criterion, asserted in test_control_points_follow_the_appendix_a_distribution.
const MIN_ENTITY_COUNTS: Dictionary = {
	"spawn_points": 2,
	"biomass_nodes": 4,
	"units": 4,
	"obstacles": 4,
}

## Floor on how far apart the two bases sit. Appendix A #2 wants 30-60s of
## setup; this is not that number — it is a guard against a map that starts both
## armies on top of each other. At the Drone's 150 px/s this is ~13s of travel,
## so the real Appendix A figure is still owed to playtesting.
const MIN_SPAWN_SEPARATION: float = 1920.0


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


func _keys(entries: Array, category: String, center_x: float, mirrored: bool) -> Array:
	var keys: Array = []
	for entry in entries:
		var pos: Vector2 = entry["position"]
		var parts: Array = [_key(_mirror(pos, center_x) if mirrored else pos)]
		for attribute in MIRRORED_ATTRIBUTES.get(category, []):
			parts.append("%s=%s" % [attribute, entry[attribute]])
		keys.append("|".join(parts))
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
			_keys(entries, category, center_x, true),
			_keys(entries, category, center_x, false),
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


func test_the_game_loads_the_map_this_file_guards() -> void:
	# Every other assertion here is worth nothing if the shipped scene reads a
	# different file. Verified by mutation: repointing the map scene's
	# definition_path at test_arena.json left this entire file green.
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	autofree(main)
	var maps: Array = []
	for child in main.get_children():
		if child is GameMap:
			maps.append(child)
	assert_eq(maps.size(), 1, "main scene instances exactly one map")
	assert_eq(maps[0].definition_path, GREYBOX_PATH, "and it reads the guarded definition")


func test_spawns_sit_apart_and_off_the_mirror_axis() -> void:
	# Two purposes. Appendix A #2 wants the bases far enough apart to allow
	# setup; and a point ON the mirror axis is its own reflection, so without
	# this the symmetry test accepts both Mothers stacked at map centre —
	# verified by mutation, it passed green.
	var def := _def()
	var center_x := _center_x(def)
	var positions: Array = []
	for spawn in def.spawn_points:
		var pos: Vector2 = spawn["position"]
		assert_ne(roundi(pos.x), roundi(center_x), "spawn at %s is off the mirror axis" % _key(pos))
		positions.append(pos)
	assert_eq(positions.size(), 2, "exactly two spawns to compare")
	assert_gt(
		positions[0].distance_to(positions[1]),
		MIN_SPAWN_SEPARATION,
		"bases are at least %d apart" % roundi(MIN_SPAWN_SEPARATION)
	)


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

	# GUT keeps running after a failed assert, so without this guard a violation
	# of the line above surfaces as an out-of-bounds engine error rather than as
	# the message that explains it.
	if central.is_empty():
		return

	var map_center := def.bounds.position + def.bounds.size / 2.0
	assert_eq(central[0]["position"], map_center, "the high-value point sits at map centre")
	for cp in peripheral:
		assert_gt(
			float(central[0]["capture_radius"]),
			float(cp["capture_radius"]),
			"central zone is larger than peripheral zone at %s" % _key(cp["position"])
		)


func test_control_point_ids_are_unique_and_named() -> void:
	# ids are how M7 (SPI-1338) will address a point for capture and ownership.
	# Two points sharing one is a silent aliasing bug that every symmetry check
	# here accepts — verified by mutation, renaming "ne" to "nw" stayed green.
	var def := _def()
	var seen: Dictionary = {}
	for cp in def.control_points:
		var id: String = cp["id"]
		assert_false(id.is_empty(), "control point at %s has an id" % _key(cp["position"]))
		assert_false(seen.has(id), "control point id '%s' is used once" % id)
		seen[id] = true


func test_every_category_has_enough_entities_to_be_a_map() -> void:
	# See MIN_ENTITY_COUNTS: these are anti-degeneracy floors, not design targets.
	var def := _def()
	assert_eq(def.spawn_points.size(), 2, "exactly 2 spawn_points")
	for category in MIN_ENTITY_COUNTS:
		if category == "spawn_points":
			continue
		var floor_count: int = MIN_ENTITY_COUNTS[category]
		assert_true(
			def.get(category).size() >= floor_count,
			(
				"%s has at least %d entries (found %d)"
				% [category, floor_count, def.get(category).size()]
			)
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


func test_obstacle_extents_sit_inside_the_map_bounds() -> void:
	# The anchor test above only sees a centre point. An obstacle is a rect
	# around that centre, so a wall can be anchored well inside the map and still
	# stick out of it — verified by mutation, resizing the walls to 80x5000 left
	# every other check in this file green while ~2340px of wall hung outside the
	# bounds and sealed the two halves apart.
	var def := _def()
	for obstacle in def.obstacles:
		var pos: Vector2 = obstacle["position"]
		var size: Vector2 = obstacle["size"]
		var extents := Rect2(pos - size / 2.0, size)
		assert_true(
			def.bounds.encloses(extents),
			(
				"obstacle at %s sized %dx%d spans %s and must stay inside bounds %s"
				% [_key(pos), roundi(size.x), roundi(size.y), extents, def.bounds]
			)
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
