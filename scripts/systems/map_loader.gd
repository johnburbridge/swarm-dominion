class_name MapLoader extends RefCounted
## Instantiates a parsed MapDefinition into a scene. Thin, tree-touching adapter:
## all validation lives in MapDefinition; this only builds nodes and returns the
## spawned references so callers can use them without re-querying the tree.

const DroneScene := preload("res://scenes/units/drone.tscn")
const MotherScene := preload("res://scenes/units/mother.tscn")
const BiomassNodeScene := preload("res://scenes/resources/biomass_node.tscn")

const CONTROL_POINT_GROUP: StringName = &"control_points"
const OBSTACLE_GROUP: StringName = &"obstacles"

## Physics layer 4 (bit value 8). The three layers below it are all taken:
## layer 1 (value 1) is unit bodies, layer 2 (value 2) is the units' own
## attack-detection Area2D (unit_base.gd's _setup_attack_area), and layer 3
## (value 4) is biomass nodes. See [code][layer_names][/code] in project.godot,
## which is the authoritative list, and main.gd's UNIT_COLLISION_MASK /
## BIOMASS_NODE_COLLISION_MASK. Giving obstacles their own layer keeps them out
## of the click-to-select point query and out of attack target detection.
const OBSTACLE_LAYER: int = 8

## Greybox placeholder fill — deliberately drab so real art reads as an upgrade,
## and dark enough to hold contrast against the light grid background.
const GREYBOX_OBSTACLE_COLOR: Color = Color(0.24, 0.24, 0.29)

## Above the background (-10), below units (0), so a unit walking against an
## obstacle stays readable.
const OBSTACLE_Z_INDEX: int = -5


## Instantiates every entity in `definition` as a child of `parent`. Returns a
## dictionary of the spawned nodes keyed by category.
static func populate(definition: MapDefinition, parent: Node) -> Dictionary:
	var result: Dictionary = {
		"mothers": [],
		"biomass_nodes": [],
		"control_points": [],
		"obstacles": [],
		"units": [],
	}
	if definition == null or parent == null:
		push_warning("MapLoader: null definition or parent")
		return result

	for spawn in definition.spawn_points:
		var mother := MotherScene.instantiate() as MotherUnit
		mother.team_id = spawn["team_id"]
		mother.position = spawn["position"]
		parent.add_child(mother)
		result["mothers"].append(mother)

	for node_def in definition.biomass_nodes:
		var node := BiomassNodeScene.instantiate() as BiomassNode
		node.position = node_def["position"]
		parent.add_child(node)
		result["biomass_nodes"].append(node)

	for cp_def in definition.control_points:
		var cp := _build_control_point(cp_def)
		parent.add_child(cp)
		result["control_points"].append(cp)

	for obstacle_def in definition.obstacles:
		var obstacle := _build_obstacle(obstacle_def)
		parent.add_child(obstacle)
		result["obstacles"].append(obstacle)

	for unit_def in definition.units:
		var unit := _build_unit(unit_def)
		if unit == null:
			continue
		parent.add_child(unit)
		result["units"].append(unit)

	return result


static func _build_control_point(cp_def: Dictionary) -> Marker2D:
	var marker := Marker2D.new()
	marker.position = cp_def["position"]
	marker.set_meta("id", cp_def["id"])
	marker.set_meta("vp_weight", cp_def["vp_weight"])
	marker.set_meta("capture_radius", cp_def["capture_radius"])
	marker.add_to_group(CONTROL_POINT_GROUP)

	var area := Area2D.new()
	area.name = "CaptureZone"
	# Placeholder is physics-inert: nothing queries it yet, and leaving it on the
	# default layer 1 (shared with units) would be a footgun. M7 (SPI-1338) sets an
	# intentional collision_layer/mask and enables monitoring when it wires capture.
	area.monitoring = false
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = cp_def["capture_radius"]
	shape.shape = circle
	area.add_child(shape)
	marker.add_child(area)
	return marker


## Builds one impassable block. The CollisionShape2D is added first because it is
## the load-bearing child — the greybox Polygon2D after it is placeholder art that
## SPI-1447 replaces, and callers index the shape at child 0.
static func _build_obstacle(obstacle_def: Dictionary) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = obstacle_def["position"]
	body.collision_layer = OBSTACLE_LAYER
	# Static geometry is detected, it never detects: a zero mask keeps it out of
	# every query rather than relying on nothing happening to look for it.
	body.collision_mask = 0
	body.add_to_group(OBSTACLE_GROUP)

	var size: Vector2 = obstacle_def["size"]
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.add_child(_build_obstacle_visual(size))
	return body


## Flat greybox fill matching the collision rect, so what you see is exactly what
## blocks movement. Both are centred on the body, which is why the polygon is
## built from half-extents rather than from the origin.
static func _build_obstacle_visual(size: Vector2) -> Polygon2D:
	var half := size / 2.0
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array(
		[-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	)
	visual.color = GREYBOX_OBSTACLE_COLOR
	visual.z_index = OBSTACLE_Z_INDEX
	return visual


static func _build_unit(unit_def: Dictionary) -> UnitBase:
	var unit_type: String = unit_def["type"]
	if unit_type != "drone":
		push_warning("MapLoader: unknown unit type '%s', skipping" % unit_type)
		return null
	var unit := DroneScene.instantiate() as UnitBase
	unit.team_id = unit_def["team_id"]
	unit.position = unit_def["position"]
	return unit
