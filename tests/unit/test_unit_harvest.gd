extends GutTest
## Tests for UnitBase HARVESTING behavior (SPI-1385).

var _drone_scene: PackedScene
var _node_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")
	_node_scene = load("res://scenes/resources/biomass_node.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


func _create_node(pos: Vector2) -> BiomassNode:
	var node := _node_scene.instantiate() as BiomassNode
	node.position = pos
	add_child_autofree(node)
	return node


# --- Entering HARVESTING and approaching ---


func test_harvest_at_enters_harvesting_and_approaches() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	var node := _create_node(Vector2(300, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	assert_eq(unit._state, UnitBase.UnitState.HARVESTING, "should set HARVESTING immediately")
	assert_eq(unit._harvest_target, node, "should store harvest target")
	var start_dist := unit.position.distance_to(node.position)
	for _i in range(30):
		await get_tree().physics_frame
	var end_dist := unit.position.distance_to(node.position)
	assert_lt(end_dist, start_dist, "should move toward the node")
	assert_eq(
		unit._state, UnitBase.UnitState.HARVESTING, "should still be HARVESTING while approaching"
	)


# --- Accruing biomass ---


func test_harvest_accrues_biomass_to_team() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_speed = 5
	unit.harvest_at(node)
	for _i in range(65):
		await get_tree().physics_frame
	assert_gt(ResourceManager.get_resources(1), 0, "team should have gathered biomass")
	assert_lt(node.current_biomass, node.max_biomass, "node should be decremented")


func test_higher_harvest_speed_accrues_faster() -> void:
	var node_a := _create_node(Vector2(0, 0))
	var node_b := _create_node(Vector2(1000, 0))
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(2, Vector2(1000, 0))
	await get_tree().process_frame
	unit_a.harvest_speed = 5
	unit_b.harvest_speed = 8
	unit_a.harvest_at(node_a)
	unit_b.harvest_at(node_b)
	for _i in range(65):
		await get_tree().physics_frame
	assert_gt(
		ResourceManager.get_resources(2),
		ResourceManager.get_resources(1),
		"faster harvester should have gathered more",
	)


# --- Auto-attack suppression ---


func test_no_auto_attack_while_harvesting() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	var enemy := _create_unit(2, Vector2(0, 0))
	await get_tree().process_frame
	for _i in range(10):
		await get_tree().physics_frame
	assert_eq(unit._state, UnitBase.UnitState.HARVESTING, "should stay HARVESTING, not ATTACKING")
	assert_null(unit._attack_target, "should not acquire an attack target while harvesting")


# --- Command cancellation ---


func test_move_to_cancels_harvesting() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	unit.move_to(Vector2(400, 0))
	assert_eq(unit._state, UnitBase.UnitState.MOVING, "move_to should override HARVESTING")
	assert_null(unit._harvest_target, "move_to should clear harvest target")


func test_attack_move_to_cancels_harvesting() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	unit.attack_move_to(Vector2(400, 0))
	assert_eq(
		unit._state, UnitBase.UnitState.ATTACK_MOVING, "attack_move should override HARVESTING"
	)
	assert_null(unit._harvest_target, "attack_move should clear harvest target")


func test_engage_unit_cancels_harvesting() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	unit.engage_unit(enemy)
	assert_eq(unit._state, UnitBase.UnitState.ENGAGING, "engage_unit should override HARVESTING")
	assert_null(unit._harvest_target, "engage_unit should clear harvest target")


# --- Animation ---


func test_is_moving_false_while_harvesting() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	assert_false(unit._is_moving, "HARVESTING should not count as moving")


# --- Dead unit ---


func test_dead_unit_ignores_harvest_at() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.take_damage(unit.max_health)
	unit.harvest_at(node)
	assert_eq(unit._state, UnitBase.UnitState.DEAD, "dead unit should stay DEAD")
	assert_null(unit._harvest_target, "dead unit should not acquire a harvest target")


# --- Depletion ---


func test_depleted_node_ends_harvest() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	node.harvest(node.max_biomass - 3)
	unit.harvest_speed = 5
	unit.harvest_at(node)
	for _i in range(90):
		await get_tree().physics_frame
	assert_true(node.is_depleted(), "precondition: node should be depleted")
	assert_eq(unit._state, UnitBase.UnitState.IDLE, "should return to IDLE after depletion")
	assert_null(unit._harvest_target, "should clear harvest target after depletion")


# --- Non-harvesters ---


func test_zero_harvest_speed_does_not_harvest() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_speed = 0.0
	unit.harvest_at(node)
	for _i in range(10):
		await get_tree().physics_frame
	assert_ne(
		unit._state,
		UnitBase.UnitState.HARVESTING,
		"zero-harvest-speed unit should not enter HARVESTING"
	)
	assert_eq(ResourceManager.get_resources(1), 0, "no biomass should be gathered")
	assert_eq(node.current_biomass, node.max_biomass, "node should not be decremented")


# --- Re-harvest after cancel ---


func test_can_reharvest_after_cancel() -> void:
	var node_a := _create_node(Vector2(0, 0))
	var node_b := _create_node(Vector2(1000, 1000))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_speed = 5
	unit.harvest_at(node_a)
	unit.move_to(Vector2(400, 0))
	assert_null(unit._harvest_target, "move_to should clear harvest target")
	unit.position = node_b.position
	unit.harvest_at(node_b)
	for _i in range(65):
		await get_tree().physics_frame
	assert_eq(unit._state, UnitBase.UnitState.HARVESTING, "should be HARVESTING the second node")
	assert_eq(unit._harvest_target, node_b, "should target the second node")
	assert_gt(ResourceManager.get_resources(1), 0, "biomass should accrue again after re-harvest")
