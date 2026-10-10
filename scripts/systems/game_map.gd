class_name GameMap extends Node2D
## A playable map (SPI-1444): parses a MapDefinition and populates itself with
## the entities it describes.
##
## The map owns its entities rather than dropping them into Main, so the scene
## tree says where things came from and a second map could be loaded without
## unpicking Main. Nothing depends on that ownership — units are found through
## the "units" group, not by tree position.

@export_file("*.json") var definition_path: String = ""

var definition: MapDefinition = null
var loaded: Dictionary = {}


func _ready() -> void:
	load_definition()


## Parses `definition_path` and instantiates its entities as children. Kept
## separate from _ready() so a caller can build a GameMap without the tree, and
## so a failed load leaves an empty-but-valid map rather than a half-built one.
## Not idempotent: calling it twice populates the map twice.
func load_definition() -> void:
	definition = MapDefinition.from_file(definition_path)
	if definition == null:
		push_warning("GameMap: could not load definition '%s'" % definition_path)
		return
	loaded = MapLoader.populate(definition, self)


## The map's playable rect, or an empty Rect2 if no definition loaded. Callers
## use this for camera limits, so an empty rect must read as "no limits" rather
## than as a zero-size world — see main.gd's has_area() guard.
func get_bounds() -> Rect2:
	return Rect2() if definition == null else definition.bounds


## The first Mother belonging to `team_id`, or null. Maps are authored with one
## Mother per team today; if a mode ever spawns two, this returns the one the
## map lists first rather than picking arbitrarily.
func get_mother_for_team(team_id: int) -> MotherUnit:
	for mother in loaded.get("mothers", []):
		if mother is MotherUnit and mother.team_id == team_id:
			return mother
	return null
