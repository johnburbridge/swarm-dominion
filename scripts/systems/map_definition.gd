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
	def.spawn_points = _parse_entries(
		data.get("spawn_points", []),
		"spawn_point",
		func(entry: Dictionary, pos: Variant) -> Dictionary:
			return {"team_id": int(entry.get("team_id", 0)), "position": pos}
	)
	def.biomass_nodes = _parse_entries(
		data.get("biomass_nodes", []),
		"biomass_node",
		func(entry: Dictionary, pos: Variant) -> Dictionary: return {"position": pos}
	)
	def.control_points = _parse_entries(
		data.get("control_points", []),
		"control_point",
		func(entry: Dictionary, pos: Variant) -> Dictionary:
			return {
				"id": String(entry.get("id", "")),
				"position": pos,
				"capture_radius": float(entry.get("capture_radius", DEFAULT_CAPTURE_RADIUS)),
				"vp_weight": int(entry.get("vp_weight", DEFAULT_VP_WEIGHT)),
			}
	)
	def.units = _parse_entries(
		data.get("units", []),
		"unit",
		func(entry: Dictionary, pos: Variant) -> Dictionary:
			return {
				"type": String(entry.get("type", "drone")),
				"team_id": int(entry.get("team_id", 0)),
				"position": pos,
			}
	)
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


## Shared skip-and-warn scaffold for parsing a JSON array of entry
## dictionaries, each of which must have a valid "position" field. Malformed
## entries and entries with invalid positions are skipped with a warning;
## [param build] receives the raw entry and the parsed position and returns
## the resulting dictionary for that entry.
static func _parse_entries(value: Variant, label: String, build: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("MapDefinition: skipping malformed %s entry" % label)
			continue
		var pos: Variant = _parse_vec2(entry.get("position"))
		if pos == null:
			push_warning("MapDefinition: skipping %s with invalid position" % label)
			continue
		result.append(build.call(entry, pos) as Dictionary)
	return result
