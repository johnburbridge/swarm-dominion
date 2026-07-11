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
