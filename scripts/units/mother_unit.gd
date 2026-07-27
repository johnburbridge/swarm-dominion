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
## Mother instead of stacking. Uses a plain counter (no RNG). (Bit-exact
## cross-platform determinism of the sin/cos placement is a separate, codebase-wide
## networking concern for M11/M12, not addressed here.)
const SPAWN_ANGLE_STEP: float = TAU / 8.0
## Offset from the Mother's center for the default rally when no explicit point is
## set: directly below, clear of the Mother's body (radius 32) plus a Drone's radius,
## so spawned Drones disperse instead of stacking on the Mother.
const DEFAULT_RALLY_OFFSET: Vector2 = Vector2(0, 96)
## Angular step between rear-fan slots while the Mother is moving. TAU / 12 (30°)
## keeps the widest slot (±2 steps) within ±60° of directly-behind — deliberately
## short of the ±90° hemisphere boundary, where the behind-ness dot product sits on
## zero and float error could tip it positive.
const REAR_FAN_STEP: float = TAU / 12.0
## Rear-fan slot offsets in REAR_FAN_STEP units, alternating outward from
## directly-behind so successive spawns disperse without leaving the rear hemisphere.
const REAR_FAN_OFFSETS: Array[int] = [0, 1, -1, 2, -2]

## Biomass charged per Drone; loaded from data/upgrade_costs.json in _ready.
## Defaults to 0 so that if the data file cannot be read the Mother fails safe
## (spend_resources rejects a 0 cost) rather than charging a stale hardcoded value.
var _spawn_cost: int = 0
## Number of Drones spawned so far; drives the placement-ring angle.
var _spawn_count: int = 0
## Explicit rally point (world space); meaningful only when _has_rally is true.
var _rally_point: Vector2 = Vector2.ZERO
## Whether the player has set an explicit rally (vs. the just-below-Mother default).
var _has_rally: bool = false
## World-space (top_level) visual for the rally point; a child so it frees with the Mother.
var _rally_marker: RallyMarker = null


func _init() -> void:
	unit_type = "mother"


func _ready() -> void:
	super._ready()
	_load_spawn_cost()
	_setup_rally_marker()


func _setup_rally_marker() -> void:
	_rally_marker = RallyMarker.new()
	# top_level so the marker's transform is world-space and the rally point stays
	# put when the (mobile) Mother moves.
	_rally_marker.top_level = true
	_rally_marker.set_team_color(TeamColors.color_for(team_id))
	_rally_marker.visible = false
	add_child(_rally_marker)


## Overrides UnitBase.set_selected to also toggle the rally marker: visible only
## when the Mother is selected AND has an explicit rally. Deselecting hides the
## marker but keeps _rally_point/_has_rally.
func set_selected(selected: bool) -> void:
	super.set_selected(selected)
	if _rally_marker != null:
		_rally_marker.visible = selected and _has_rally


## Records an explicit rally point, moves the marker there, and shows it if the
## Mother is currently selected.
func set_rally_point(pos: Vector2) -> void:
	_rally_point = pos
	_has_rally = true
	if _rally_marker != null:
		_rally_marker.global_position = pos
		_rally_marker.visible = _is_selected


func has_rally() -> bool:
	return _has_rally


func get_rally_point() -> Vector2:
	return _rally_point


## Unit vector pointing behind the Mother relative to her current movement, or
## Vector2.ZERO when she is stationary. velocity is refreshed by _process_movement()
## every physics frame while moving and zeroed on arrival, so a non-zero velocity is
## the "is moving" signal, and it is what the rear-facing placement keys off (SPI-1429).
func _rear_direction() -> Vector2:
	if velocity == Vector2.ZERO:
		return Vector2.ZERO
	return -velocity.normalized()


## Single source of truth for where a spawned Drone goes: the explicit rally if set,
## else DEFAULT_RALLY_OFFSET trailing behind a moving Mother — a fixed southward
## default would park Drones in the path of a southbound Mother — or straight below
## her when she is stationary.
func get_effective_rally() -> Vector2:
	if _has_rally:
		return _rally_point
	var rear := _rear_direction()
	if rear == Vector2.ZERO:
		return position + DEFAULT_RALLY_OFFSET
	return position + rear * DEFAULT_RALLY_OFFSET.length()


## Ring angle for the next spawn: fanned behind the Mother while she is moving, else
## the original fixed ring (SPI-1422) so stationary placement is unchanged.
func _spawn_angle() -> float:
	var rear := _rear_direction()
	if rear == Vector2.ZERO:
		return _spawn_count * SPAWN_ANGLE_STEP
	var slot: int = REAR_FAN_OFFSETS[_spawn_count % REAR_FAN_OFFSETS.size()]
	return rear.angle() + slot * REAR_FAN_STEP


func is_auto_targetable() -> bool:
	return false


## The biomass cost to spawn one Drone from this Mother (loaded from data).
func get_spawn_cost() -> int:
	return _spawn_cost


## Convert _spawn_cost biomass into a new Level 1 Drone on this Mother's team,
## placed clear of the Mother's body, and announce it. Returns the new Drone, or
## null if the team cannot afford it (no biomass spent, nothing created).
func spawn_unit() -> UnitBase:
	if not ResourceManager.spend_resources(team_id, _spawn_cost):
		return null
	var drone := DroneScene.instantiate() as UnitBase
	drone.team_id = team_id
	# Both rings wrap (every 8 spawns stationary, every 5 moving), so a later Drone
	# eventually stacks on an earlier one. Rally points (SPI-1424) are the intended
	# dispersal mechanism — the Drone walks off the ring on the spawn frame anyway.
	var angle := _spawn_angle()
	drone.position = position + Vector2.from_angle(angle) * SPAWN_RADIUS
	_spawn_count += 1
	get_parent().add_child(drone)
	drone.play_spawn_emerge()
	drone.move_to(get_effective_rally())
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
