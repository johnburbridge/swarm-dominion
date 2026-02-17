extends GutTest
## Tests for attack-move behavior (SPI-1371).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


func test_attack_move_sets_state() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.attack_move_to(Vector2(500, 0))
	assert_eq(
		unit._state,
		UnitBase.UnitState.ATTACK_MOVING,
		"attack_move_to should set state to ATTACK_MOVING",
	)
	assert_true(unit._has_attack_move_destination, "should set _has_attack_move_destination")


func test_dead_unit_ignores_attack_move() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.take_damage(unit.max_health)
	unit.attack_move_to(Vector2(500, 0))
	assert_eq(
		unit._state,
		UnitBase.UnitState.DEAD,
		"dead unit should remain in DEAD state after attack_move_to",
	)


func test_attack_move_engages_enemy_in_range() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	attacker.attack_move_to(Vector2(500, 0))
	# Place enemy within attack range along the path
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	# Allow physics to detect the enemy and attack-move to engage
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		attacker._state,
		UnitBase.UnitState.ATTACKING,
		"attack-moving unit should transition to ATTACKING when enemy in range",
	)
	assert_eq(attacker._attack_target, enemy, "should target the enemy")


func test_attack_move_resumes_after_kill() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	attacker.attack_move_to(Vector2(500, 0))
	# Let attacker detect and engage
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		attacker._state,
		UnitBase.UnitState.ATTACKING,
		"should be attacking the enemy",
	)
	# Kill enemy
	enemy.take_damage(enemy.max_health)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		attacker._state,
		UnitBase.UnitState.ATTACK_MOVING,
		"should resume ATTACK_MOVING after target dies",
	)
	assert_true(
		attacker._has_attack_move_destination,
		"should still have attack move destination",
	)


func test_attack_move_idles_on_arrival() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	# Attack-move to a very close position (just past ARRIVAL_THRESHOLD)
	unit.attack_move_to(Vector2(10, 0))
	# Process enough frames for arrival
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		unit._state,
		UnitBase.UnitState.IDLE,
		"should be IDLE after arriving at attack-move destination",
	)
	assert_false(
		unit._has_attack_move_destination,
		"_has_attack_move_destination should be cleared on arrival",
	)


func test_move_to_clears_attack_move() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.attack_move_to(Vector2(500, 0))
	assert_true(unit._has_attack_move_destination)
	# Issue regular move command
	unit.move_to(Vector2(200, 0))
	assert_eq(
		unit._state,
		UnitBase.UnitState.MOVING,
		"move_to should override to MOVING state",
	)
	assert_false(
		unit._has_attack_move_destination,
		"move_to should clear _has_attack_move_destination",
	)
