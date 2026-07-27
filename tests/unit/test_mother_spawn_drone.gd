extends GutTest
## Unit tests for Mother drone spawning (SPI-1422): spawn_unit() charges biomass
## via ResourceManager, places a Level 1 Drone clear of the Mother on its team,
## announces via EventBus.unit_spawned, and returns the Drone (or null when the
## team cannot afford it).

var _mother_scene: PackedScene


func before_all() -> void:
	_mother_scene = load("res://scenes/units/mother.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _create_mother(tid: int, pos: Vector2) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = pos
	add_child_autofree(mother)
	return mother


func _expected_spawn_cost() -> int:
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return int(json.data["spawn_costs"]["drone"]["biomass"])


func test_spawn_cost_loaded_from_data() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	assert_eq(
		mother._spawn_cost, _expected_spawn_cost(), "cost should load from upgrade_costs.json"
	)


func test_successful_spawn_deducts_cost() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var before := ResourceManager.get_resources(1)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_eq(
		ResourceManager.get_resources(1),
		before - _expected_spawn_cost(),
		"biomass should drop by the spawn cost"
	)


func test_successful_spawn_returns_level1_drone_on_team() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_not_null(drone, "spawn should return the new Drone")
	assert_eq(drone.unit_type, "drone", "spawned unit should be a Drone")
	assert_eq(drone.team_id, 1, "Drone should be on the Mother's team")


func test_spawn_emits_unit_spawned() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	watch_signals(EventBus)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_signal_emitted(EventBus, "unit_spawned", "spawn should announce via EventBus")
	# The announced unit must be the spawned Drone (not some other node).
	assert_signal_emitted_with_parameters(EventBus, "unit_spawned", [drone])


func test_spawned_drone_clear_of_mother_and_controllable() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_gte(
		drone.position.distance_to(mother.position),
		48.0,
		"Drone must not overlap the Mother's body"
	)
	assert_true(drone.is_in_group("units"), "Drone should join the units group (controllable)")
	assert_eq(drone.get_parent(), mother.get_parent(), "Drone should be a sibling of the Mother")


func test_insufficient_biomass_no_spawn() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	# team 1 has 0 biomass (reset in before_each), below the spawn cost
	watch_signals(EventBus)
	var units_before := get_tree().get_nodes_in_group("units").size()
	var drone := mother.spawn_unit()
	assert_null(drone, "spawn should fail and return null")
	assert_eq(ResourceManager.get_resources(1), 0, "no biomass should be deducted")
	assert_eq(
		get_tree().get_nodes_in_group("units").size(), units_before, "no Drone should be created"
	)
	assert_signal_not_emitted(EventBus, "unit_spawned", "no spawn signal on failure")


## Puts the Mother under a move order in `heading`, far enough that move_to() does
## not short-circuit on ARRIVAL_THRESHOLD, and returns that heading.
func _send(mother: MotherUnit, heading: Vector2) -> Vector2:
	mother.move_to(mother.position + heading * 10.0)
	return heading


func test_moving_mother_places_drone_behind_her() -> void:
	# SPI-1429: the ring's base angle follows the Mother's heading so a spawned
	# Drone never pops into the path of a moving Mother.
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var heading := _send(mother, Vector2(200, 0))  # moving east
	var drone := mother.spawn_unit()
	autofree(drone)
	var offset := drone.position - mother.position
	assert_lt(offset.dot(heading), 0.0, "Drone should spawn behind a moving Mother")
	assert_almost_eq(
		offset.length(),
		MotherUnit.SPAWN_RADIUS,
		0.01,
		"the rear fan must keep the Drone clear of the Mother's body, as the ring does"
	)


func test_consecutive_moving_spawns_stay_behind_and_distinct() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 500)
	var heading := _send(mother, Vector2(0, 200))  # moving south
	var seen: Array[Vector2] = []
	for i in 5:
		var drone := mother.spawn_unit()
		autofree(drone)
		assert_not_null(drone, "spawn %d should succeed" % i)
		var offset := drone.position - mother.position
		assert_lt(offset.dot(heading), 0.0, "spawn %d should stay behind the Mother" % i)
		# Separation, not mere distinctness: this is what pins REAR_FAN_STEP wide
		# enough that adjacent fan slots clear a Drone's 32px diameter.
		for prior in seen:
			assert_gte(
				drone.position.distance_to(prior),
				32.0,
				"spawn %d should clear a Drone's width from every earlier spawn" % i
			)
		seen.append(drone.position)


func test_blocked_mother_still_spawns_behind_her() -> void:
	# Companion to the rally-side guard: a Mother jammed against an obstacle has
	# velocity ZERO from move_and_slide while still under a move order.
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var heading := _send(mother, Vector2(0, 200))
	mother.velocity = Vector2.ZERO  # as move_and_slide leaves a blocked body
	var drone := mother.spawn_unit()
	autofree(drone)
	var offset := drone.position - mother.position
	assert_lt(offset.dot(heading), 0.0, "a blocked but still-commanded Mother spawns behind her")


func test_stationary_ring_placement_unchanged() -> void:
	# Regression guard: a stationary Mother keeps the original SPI-1422 ring.
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 200)
	var first := mother.spawn_unit()
	autofree(first)
	var second := mother.spawn_unit()
	autofree(second)
	assert_almost_eq(
		first.position,
		mother.position + Vector2.from_angle(0.0) * MotherUnit.SPAWN_RADIUS,
		Vector2(0.01, 0.01),
		"first stationary spawn should sit at the original ring angle 0"
	)
	assert_almost_eq(
		second.position,
		mother.position + Vector2.from_angle(MotherUnit.SPAWN_ANGLE_STEP) * MotherUnit.SPAWN_RADIUS,
		Vector2(0.01, 0.01),
		"second stationary spawn should advance by SPAWN_ANGLE_STEP as before"
	)


func test_repeated_spawns_fan_out() -> void:
	var mother := _create_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 200)
	var first := mother.spawn_unit()
	autofree(first)
	var second := mother.spawn_unit()
	autofree(second)
	assert_not_null(first, "first spawn should succeed")
	assert_not_null(second, "second spawn should succeed")
	assert_ne(first.position, second.position, "successive spawns should not stack")
