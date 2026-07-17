class_name MapDefinition extends RefCounted
## Parsed, validated map definition loaded from a JSON file under
## data/map_definitions/. Pure data (no scene tree) so it is fully
## headless-testable. MapLoader turns a MapDefinition into instantiated nodes.

const DEFAULT_CAPTURE_RADIUS: float = 96.0
const DEFAULT_VP_WEIGHT: int = 1

var map_name: String = ""
var bounds: Rect2 = Rect2()
var spawn_points: Array[Dictionary] = []
var biomass_nodes: Array[Dictionary] = []
var control_points: Array[Dictionary] = []
var units: Array[Dictionary] = []


## Loads and parses a definition file. Returns null on a missing file,
## unparseable JSON, or a non-object root.
static func from_file(path: String) -> MapDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("MapDefinition: could not open '%s'" % path)
		return null
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning("MapDefinition: failed to parse '%s': %s" % [path, json.get_error_message()])
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("MapDefinition: '%s' root is not a JSON object" % path)
		return null
	return from_dict(json.data)


## Builds a validated definition from an already-parsed dictionary. Always
## returns a MapDefinition; malformed entries are skipped with a warning.
static func from_dict(data: Dictionary) -> MapDefinition:
	var def := MapDefinition.new()
	def.map_name = String(data.get("name", ""))
	def.bounds = _parse_bounds(data.get("bounds", {}))
	def.spawn_points = _parse_spawn_points(data.get("spawn_points", []))
	def.biomass_nodes = _parse_biomass_nodes(data.get("biomass_nodes", []))
	def.control_points = _parse_control_points(data.get("control_points", []))
	def.units = _parse_units(data.get("units", []))
	return def


static func _parse_bounds(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	return Rect2(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("width", 0.0)),
		float(value.get("height", 0.0))
	)


## Converts a [x, y] JSON array to Vector2. Returns null for malformed input so
## the caller can skip the entry.
static func _parse_vec2(value: Variant) -> Variant:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return null
	return Vector2(float(value[0]), float(value[1]))


static func _parse_spawn_points(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("MapDefinition: skipping malformed spawn_point entry")
			continue
		var pos: Variant = _parse_vec2(entry.get("position"))
		if pos == null:
			push_warning("MapDefinition: skipping spawn_point with invalid position")
			continue
		result.append({"team_id": int(entry.get("team_id", 0)), "position": pos})
	return result


static func _parse_biomass_nodes(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("MapDefinition: skipping malformed biomass_node entry")
			continue
		var pos: Variant = _parse_vec2(entry.get("position"))
		if pos == null:
			push_warning("MapDefinition: skipping biomass_node with invalid position")
			continue
		result.append({"position": pos})
	return result


static func _parse_control_points(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("MapDefinition: skipping malformed control_point entry")
			continue
		var pos: Variant = _parse_vec2(entry.get("position"))
		if pos == null:
			push_warning("MapDefinition: skipping control_point with invalid position")
			continue
		(
			result
			. append(
				{
					"id": String(entry.get("id", "")),
					"position": pos,
					"capture_radius": float(entry.get("capture_radius", DEFAULT_CAPTURE_RADIUS)),
					"vp_weight": int(entry.get("vp_weight", DEFAULT_VP_WEIGHT)),
				}
			)
		)
	return result


static func _parse_units(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("MapDefinition: skipping malformed unit entry")
			continue
		var pos: Variant = _parse_vec2(entry.get("position"))
		if pos == null:
			push_warning("MapDefinition: skipping unit with invalid position")
			continue
		(
			result
			. append(
				{
					"type": String(entry.get("type", "drone")),
					"team_id": int(entry.get("team_id", 0)),
					"position": pos,
				}
			)
		)
	return result
