class_name MapLoader extends RefCounted
## Instantiates a parsed MapDefinition into a scene. Thin, tree-touching adapter:
## all validation lives in MapDefinition; this only builds nodes and returns the
## spawned references so callers can use them without re-querying the tree.

const DroneScene := preload("res://scenes/units/drone.tscn")
const MotherScene := preload("res://scenes/units/mother.tscn")
const BiomassNodeScene := preload("res://scenes/resources/biomass_node.tscn")

const CONTROL_POINT_GROUP: StringName = &"control_points"

## Temporary team tint — a stopgap until the SPI-1436 palette-swap shader lands.
const TEAM_TINTS: Dictionary = {
	1: Color(0.6, 1.0, 0.6),
	2: Color(1.0, 0.7, 0.7),
}


## Instantiates every entity in `definition` as a child of `parent`. Returns a
## dictionary of the spawned nodes keyed by category.
static func populate(definition: MapDefinition, parent: Node) -> Dictionary:
	var result: Dictionary = {
		"mothers": [],
		"biomass_nodes": [],
		"control_points": [],
		"units": [],
	}
	if definition == null or parent == null:
		push_warning("MapLoader: null definition or parent")
		return result

	for spawn in definition.spawn_points:
		var mother := MotherScene.instantiate() as MotherUnit
		mother.team_id = spawn["team_id"]
		mother.position = spawn["position"]
		_apply_team_tint(mother, spawn["team_id"])
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


static func _build_unit(unit_def: Dictionary) -> UnitBase:
	var unit_type: String = unit_def["type"]
	if unit_type != "drone":
		push_warning("MapLoader: unknown unit type '%s', skipping" % unit_type)
		return null
	var unit := DroneScene.instantiate() as UnitBase
	unit.team_id = unit_def["team_id"]
	unit.position = unit_def["position"]
	_apply_team_tint(unit, unit_def["team_id"])
	return unit


static func _apply_team_tint(node: CanvasItem, team_id: int) -> void:
	node.modulate = TEAM_TINTS.get(team_id, Color.WHITE)
