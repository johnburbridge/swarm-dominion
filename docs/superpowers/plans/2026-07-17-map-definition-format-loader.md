# Map-Definition Format + Loader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `main.gd`'s hardcoded entity placement with a data-driven JSON map-definition format and a loader that instantiates a map from it.

**Architecture:** Two isolated classes. `MapDefinition` (RefCounted) parses and validates a JSON definition into typed fields — pure data, no scene tree, fully headless-testable. `MapLoader` (RefCounted) is a thin adapter that turns a `MapDefinition` into instantiated nodes and returns references to them. `main.gd` calls both and applies camera bounds. Control points instantiate as placeholder markers until M7 builds the real scene.

**Tech Stack:** Godot 4.7 (GDScript), GUT 9.5.0 for tests, gdformat/gdlint.

## Global Constraints

- **Engine:** Godot 4.7.stable. GDScript only.
- **GDScript conventions:** `UPPER_SNAKE_CASE` consts, `snake_case` typed vars, leading `_` for private, type hints on params and returns. Regular `var` declared before `@onready var` (gdlint class-definitions-order).
- **JSON loading pattern (match existing):** `FileAccess.open` → `JSON.new().parse` → `push_warning` + sensible defaults on failure (see `scripts/units/unit_base.gd:198`).
- **New `class_name` files need an import before types resolve:** run `godot --headless --import` after creating each new script, or other scripts/tests fail with "Could not find type".
- **GUT false-green gotcha:** GUT silently skips a parse-errored test file and still reports "All tests passed". After adding a test file, confirm the Scripts/Tests counts rose — grep the run output for the test filename; don't trust the summary alone.
- **GUT run command (`.gutconfig.json` sets `dirs`, so `-gtest=` is ignored):** run the full suite and grep:
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- **Formatting/lint before every commit:** `gdformat scripts/ tests/` then `gdlint scripts/` (gdformat may collapse multi-line `Vector2(...)` to one line — run it on new files before committing).
- **Commits:** atomic, conventional-commit style. End the message body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch:** `spi-1443-map-definition-format-loader` (already created).

---

## File Structure

| File | Responsibility |
|------|----------------|
| `scripts/systems/map_definition.gd` | New — `MapDefinition`: parse + validate JSON into typed fields (pure data) |
| `scripts/systems/map_loader.gd` | New — `MapLoader`: instantiate a `MapDefinition` into a scene, return spawned refs |
| `data/map_definitions/test_arena.json` | New — sample definition reproducing today's scene (symmetric) |
| `scripts/main.gd` | Modify — replace hardcoded spawns with a map load + camera bounds |
| `tests/unit/test_map_definition.gd` | New — parse-layer tests |
| `tests/unit/test_map_loader.gd` | New — instantiation-layer tests |

---

## Task 1: `MapDefinition` parse layer + sample definition

**Files:**
- Create: `scripts/systems/map_definition.gd`
- Create: `data/map_definitions/test_arena.json`
- Test: `tests/unit/test_map_definition.gd`

**Interfaces:**
- Consumes: nothing (leaf).
- Produces:
  - `class_name MapDefinition extends RefCounted`
  - `static func from_file(path: String) -> MapDefinition` — returns `null` on missing file / unparseable JSON / non-object root.
  - `static func from_dict(data: Dictionary) -> MapDefinition` — always returns a `MapDefinition` (never null).
  - Fields: `map_name: String`, `bounds: Rect2`, `spawn_points: Array[Dictionary]`, `biomass_nodes: Array[Dictionary]`, `control_points: Array[Dictionary]`, `units: Array[Dictionary]`.
  - Entry shapes: spawn_point `{team_id: int, position: Vector2}`; biomass_node `{position: Vector2}`; control_point `{id: String, position: Vector2, capture_radius: float, vp_weight: int}`; unit `{type: String, team_id: int, position: Vector2}`.
  - Consts: `DEFAULT_CAPTURE_RADIUS := 96.0`, `DEFAULT_VP_WEIGHT := 1`.

- [ ] **Step 1: Create the sample definition** `data/map_definitions/test_arena.json`

```json
{
  "name": "Test Arena",
  "bounds": { "x": 0, "y": 0, "width": 1920, "height": 1080 },
  "spawn_points": [
    { "team_id": 1, "position": [760, 400] },
    { "team_id": 2, "position": [1160, 400] }
  ],
  "biomass_nodes": [
    { "position": [500, 400] },
    { "position": [950, 300] },
    { "position": [950, 700] },
    { "position": [1400, 400] }
  ],
  "control_points": [
    { "id": "center", "position": [960, 540], "capture_radius": 96, "vp_weight": 3 }
  ],
  "units": [
    { "type": "drone", "team_id": 1, "position": [700, 480] },
    { "type": "drone", "team_id": 1, "position": [760, 540] },
    { "type": "drone", "team_id": 1, "position": [820, 480] },
    { "type": "drone", "team_id": 1, "position": [760, 600] },
    { "type": "drone", "team_id": 2, "position": [1100, 480] },
    { "type": "drone", "team_id": 2, "position": [1160, 540] },
    { "type": "drone", "team_id": 2, "position": [1220, 480] }
  ]
}
```

- [ ] **Step 2: Write the failing test** `tests/unit/test_map_definition.gd`

```gdscript
extends GutTest
## Tests for MapDefinition parse/validate layer (SPI-1443).


func _valid_dict() -> Dictionary:
	return {
		"name": "Sample",
		"bounds": {"x": 0, "y": 0, "width": 1920, "height": 1080},
		"spawn_points": [{"team_id": 1, "position": [760, 400]}],
		"biomass_nodes": [{"position": [500, 400]}, {"position": [950, 300]}],
		"control_points": [{"id": "center", "position": [960, 540], "capture_radius": 96, "vp_weight": 3}],
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
	var def := MapDefinition.from_dict({
		"biomass_nodes": [{"position": [500, 400]}, {"no_position": true}, {"position": [1, 2]}],
	})
	assert_eq(def.biomass_nodes.size(), 2, "bad entry skipped, two valid retained")


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
```

- [ ] **Step 3: Run the suite to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/gut1.log | grep -iE "test_map_definition|Parser Error|Could not find|failing|passing"`
Expected: parse error / "Could not find type MapDefinition" (the class does not exist yet). This is the RED state.

- [ ] **Step 4: Create the implementation** `scripts/systems/map_definition.gd`

```gdscript
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
		result.append(
			{
				"id": String(entry.get("id", "")),
				"position": pos,
				"capture_radius": float(entry.get("capture_radius", DEFAULT_CAPTURE_RADIUS)),
				"vp_weight": int(entry.get("vp_weight", DEFAULT_VP_WEIGHT)),
			}
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
		result.append(
			{
				"type": String(entry.get("type", "drone")),
				"team_id": int(entry.get("team_id", 0)),
				"position": pos,
			}
		)
	return result
```

- [ ] **Step 5: Import so the new `class_name` resolves**

Run: `godot --headless --import 2>&1 | tail -5`
Expected: completes without a fatal error (import warnings are fine).

- [ ] **Step 6: Run the suite to verify the new tests pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/gut1.log | grep -iE "test_map_definition\.gd|[0-9]+ passing|[0-9]+ failing"`
Expected: `test_map_definition.gd` appears in the Scripts list (confirms it was collected, not skipped) and `0 failing`. If the filename is absent, the file parse-errored — fix and rerun (do not trust the summary).

- [ ] **Step 7: Format, lint, commit**

```bash
gdformat scripts/systems/map_definition.gd tests/unit/test_map_definition.gd
gdlint scripts/systems/map_definition.gd
git add scripts/systems/map_definition.gd data/map_definitions/test_arena.json tests/unit/test_map_definition.gd
git commit -m "$(cat <<'EOF'
feat: add MapDefinition parse layer + sample map (SPI-1443)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `MapLoader` instantiation layer

**Files:**
- Create: `scripts/systems/map_loader.gd`
- Test: `tests/unit/test_map_loader.gd`

**Interfaces:**
- Consumes: `MapDefinition` (Task 1) and its field/entry shapes.
- Produces:
  - `class_name MapLoader extends RefCounted`
  - `static func populate(definition: MapDefinition, parent: Node) -> Dictionary` — instantiates entities as children of `parent`; returns `{"mothers": Array, "biomass_nodes": Array, "control_points": Array, "units": Array}` of the spawned nodes. Null `definition`/`parent` → warns and returns the empty-arrays dict.
  - `const CONTROL_POINT_GROUP := &"control_points"` — control-point placeholders are `Marker2D` nodes added to this group, with `set_meta("id"/"vp_weight"/"capture_radius", ...)` and a child `Area2D` named `"CaptureZone"` holding a `CircleShape2D` of `capture_radius`.

- [ ] **Step 1: Write the failing test** `tests/unit/test_map_loader.gd`

```gdscript
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
		"control_points": [{"id": "center", "position": [960, 540], "capture_radius": 96, "vp_weight": 3}],
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
	var loaded := MapLoader.populate(_def({"units": [{"type": "dragon", "team_id": 1, "position": [0, 0]}]}), _parent)
	assert_eq(loaded["units"].size(), 0, "unknown type skipped")


func test_populate_null_definition_returns_empty() -> void:
	var loaded := MapLoader.populate(null, _parent)
	assert_eq(loaded["mothers"].size(), 0, "no mothers")
	assert_eq(loaded["biomass_nodes"].size(), 0, "no biomass nodes")
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/gut2.log | grep -iE "test_map_loader|Parser Error|Could not find|failing"`
Expected: "Could not find type MapLoader" / parse error. RED state.

- [ ] **Step 3: Create the implementation** `scripts/systems/map_loader.gd`

```gdscript
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
```

- [ ] **Step 4: Import so the new `class_name` resolves**

Run: `godot --headless --import 2>&1 | tail -5`
Expected: completes without a fatal error.

- [ ] **Step 5: Run the suite to verify the new tests pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/gut2.log | grep -iE "test_map_loader\.gd|[0-9]+ passing|[0-9]+ failing"`
Expected: `test_map_loader.gd` present in the Scripts list and `0 failing`.

- [ ] **Step 6: Format, lint, commit**

```bash
gdformat scripts/systems/map_loader.gd tests/unit/test_map_loader.gd
gdlint scripts/systems/map_loader.gd
git add scripts/systems/map_loader.gd tests/unit/test_map_loader.gd
git commit -m "$(cat <<'EOF'
feat: add MapLoader to instantiate map definitions (SPI-1443)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `main.gd` integration

**Files:**
- Modify: `scripts/main.gd` (remove `_spawn_test_units`, `_spawn_biomass_nodes`, unused scene preloads; add `_load_map`, `_find_player_mother`, `_apply_camera_bounds`)

**Interfaces:**
- Consumes: `MapDefinition.from_file` (Task 1), `MapLoader.populate` (Task 2), and its returned `{"mothers": Array, ...}` dict.
- Produces: nothing downstream (top-level scene controller).

- [ ] **Step 1: Replace `_ready` and the spawn helpers in `scripts/main.gd`**

Delete the constants `DroneScene`, `BiomassNodeScene`, `MotherScene` (lines 5-7 — no longer used). Delete `_spawn_test_units()` and `_spawn_biomass_nodes()` entirely. Replace the body of `_ready()` and add the three helpers:

```gdscript
func _ready() -> void:
	print("Swarm Dominion initialized")
	_load_map("res://data/map_definitions/test_arena.json")
	_minimap.set_camera(_camera)


func _load_map(path: String) -> void:
	var definition := MapDefinition.from_file(path)
	if definition == null:
		push_warning("Main: failed to load map '%s'" % path)
		return
	var loaded := MapLoader.populate(definition, self)
	_player_mother = _find_player_mother(loaded["mothers"])
	_apply_camera_bounds(definition.bounds)


func _find_player_mother(mothers: Array) -> MotherUnit:
	for m in mothers:
		if m is MotherUnit and m.team_id == PLAYER_TEAM_ID:
			return m
	return null


func _apply_camera_bounds(bounds: Rect2) -> void:
	if bounds.size == Vector2.ZERO:
		return
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.position.x + bounds.size.x)
	_camera.limit_bottom = int(bounds.position.y + bounds.size.y)
```

(Keep everything else in `main.gd` unchanged — selection, commands, groups, the `_player_mother` field and its `KEY_B` debug-spawn use.)

- [ ] **Step 2: Verify the full test suite still passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee /tmp/gut3.log | grep -iE "[0-9]+ passing|[0-9]+ failing"`
Expected: `0 failing` (no test targets `main.gd` directly; this confirms nothing regressed).

- [ ] **Step 3: Smoke-test the scene headless**

Run: `godot --headless --path . scenes/main/main.tscn --quit-after 5 2>&1 | grep -iE "Swarm Dominion initialized|SCRIPT ERROR|ERROR|push_warning|failed"`
Expected: `Swarm Dominion initialized` printed; **no** `SCRIPT ERROR` and no map-load warning. (Godot's `--quit-after N` exits after N frames so the scene doesn't loop forever.)

- [ ] **Step 4: Format, lint, commit**

```bash
gdformat scripts/main.gd
gdlint scripts/main.gd
git add scripts/main.gd
git commit -m "$(cat <<'EOF'
refactor: load primary scene from map definition (SPI-1443)

Replace hardcoded entity placement in main.gd with a data-driven
map load via MapDefinition + MapLoader.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- Schema (bounds, spawn points, biomass nodes, control points, units) → Task 1 (sample JSON + `MapDefinition` fields). ✓
- Loader instantiates nodes/control points/spawn points into a scene → Task 2 (`MapLoader.populate`). ✓
- `main.gd` no longer hardcodes placement → Task 3. ✓
- At least one definition parses + loads end-to-end → Task 1 `test_from_file_parses_sample_end_to_end` + Task 3 smoke test. ✓
- Unit tests, parse valid + soft-handle malformed → Task 1 (`test_malformed_entry_is_skipped...`, `test_from_file_missing_returns_null`, defaults tests) + Task 2 (null definition, unknown unit type). ✓
- Control points as placeholder markers in `"control_points"` group with `capture_radius`/`vp_weight` → Task 2. ✓
- Temporary team tint (SPI-1436 stopgap) → Task 2 `_apply_team_tint`. ✓
- Camera bounds from `bounds` in `main.gd` → Task 3. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"/vague steps — every code step shows complete code. ✓

**Type consistency:** `MapDefinition.from_dict`/`from_file`, field names (`spawn_points`, `biomass_nodes`, `control_points`, `units`, `bounds`, `map_name`), `MapLoader.populate` return keys (`mothers`/`biomass_nodes`/`control_points`/`units`), `CONTROL_POINT_GROUP`, and `DEFAULT_CAPTURE_RADIUS`/`DEFAULT_VP_WEIGHT` are used identically across tasks and tests. ✓
