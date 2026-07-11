class_name MotherUnit extends UnitBase
## The Mother: a large, slow, high-HP command unit. It cannot harvest and cannot
## auto-attack — both fall out of the "mother" stats entry having no
## harvest_speed / attack_range (they default to 0, so harvest_at() no-ops and
## no attack Area2D is built). It is also never auto-targeted by enemies. It
## converts stored biomass into Level 1 Drones via spawn_unit() (SPI-1422).
## Rally points come in a later M4 story (SPI-1424).

const DroneScene := preload("res://scenes/units/drone.tscn")

## Distance from the Mother's center at which spawned Drones appear. 60 exceeds
## the Mother's body radius (32) plus a Drone's radius (16), so a spawned Drone
## never overlaps the Mother.
const SPAWN_RADIUS: float = 60.0
## Angular step between successive spawns so repeated Drones fan out around the
## Mother instead of stacking. Uses a plain counter (no randf) for lockstep safety.
const SPAWN_ANGLE_STEP: float = TAU / 8.0

## Biomass charged per Drone; loaded from data/upgrade_costs.json in _ready.
## Defaults to 0 so that if the data file cannot be read the Mother fails safe
## (spend_resources rejects a 0 cost) rather than charging a stale hardcoded value.
var _spawn_cost: int = 0
## Number of Drones spawned so far; drives the placement-ring angle.
var _spawn_count: int = 0


func _init() -> void:
	unit_type = "mother"


func _ready() -> void:
	super._ready()
	_load_spawn_cost()


func is_auto_targetable() -> bool:
	return false


## Convert _spawn_cost biomass into a new Level 1 Drone on this Mother's team,
## placed clear of the Mother's body, and announce it. Returns the new Drone, or
## null if the team cannot afford it (no biomass spent, nothing created).
func spawn_unit() -> UnitBase:
	if not ResourceManager.spend_resources(team_id, _spawn_cost):
		return null
	var drone := DroneScene.instantiate() as UnitBase
	drone.team_id = team_id
	var angle := _spawn_count * SPAWN_ANGLE_STEP
	drone.position = position + Vector2.from_angle(angle) * SPAWN_RADIUS
	_spawn_count += 1
	get_parent().add_child(drone)
	EventBus.unit_spawned.emit(drone)
	return drone


func _load_spawn_cost() -> void:
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	if not file:
		push_warning("MotherUnit: Could not open upgrade_costs.json")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning(
			"MotherUnit: Failed to parse upgrade_costs.json: %s" % json.get_error_message()
		)
		return
	var data: Dictionary = json.data
	var spawn_costs: Dictionary = data.get("spawn_costs", {})
	var drone_cost: Dictionary = spawn_costs.get("drone", {})
	_spawn_cost = int(drone_cost.get("biomass", _spawn_cost))
