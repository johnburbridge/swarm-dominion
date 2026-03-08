extends GutTest
## Tests for UnitBase engage-unit behavior (SPI-1381).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


# --- State transition tests ---


func test_engage_sets_state_to_engaging() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	attacker.engage_unit(enemy)
	assert_eq(attacker._state, UnitBase.UnitState.ENGAGING, "should set ENGAGING state")
	assert_eq(attacker._engage_target, enemy, "should store engage target")


func test_dead_unit_ignores_engage() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	attacker.take_damage(attacker.max_health)
	attacker.engage_unit(enemy)
	assert_eq(attacker._state, UnitBase.UnitState.DEAD, "dead unit should stay DEAD")


func test_engage_invalid_target_ignored() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var friendly := _create_unit(1, Vector2(500, 0))
	await get_tree().process_frame
	attacker.engage_unit(friendly)
	assert_eq(
		attacker._state, UnitBase.UnitState.IDLE, "friendly target should not trigger ENGAGING"
	)


func test_engage_stores_offset() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	var offset := Vector2(30, 20)
	attacker.engage_unit(enemy, offset)
	assert_eq(attacker._engage_offset, offset, "should store approach offset")


# --- Stop and attack when in range ---


func test_engage_stops_and_attacks_when_in_range() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	attacker.engage_unit(enemy)
	await get_tree().physics_frame
	assert_eq(attacker._state, UnitBase.UnitState.ATTACKING, "should attack when target in range")
	assert_eq(attacker._attack_target, enemy, "should have enemy as attack target")


# --- Re-engage when target moves ---


func test_engage_re_pursues_when_target_leaves_range() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	attacker.engage_unit(enemy)
	await get_tree().physics_frame
	assert_eq(attacker._state, UnitBase.UnitState.ATTACKING, "precondition: ATTACKING")
	enemy.position = Vector2(500, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		attacker._state, UnitBase.UnitState.ENGAGING, "should re-engage when target exits range"
	)
	assert_eq(attacker._engage_target, enemy, "should keep same engage target")


# --- Target death ---


func test_engage_clears_on_target_death() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	attacker.engage_unit(enemy)
	assert_eq(attacker._state, UnitBase.UnitState.ENGAGING)
	enemy.take_damage(enemy.max_health)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_null(attacker._engage_target, "engage target should clear on death")
	assert_eq(attacker._state, UnitBase.UnitState.IDLE, "should return to IDLE")


# --- Command cancellation ---


func test_move_to_cancels_engage() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	attacker.engage_unit(enemy)
	attacker.move_to(Vector2(200, 0))
	assert_eq(attacker._state, UnitBase.UnitState.MOVING, "move_to should override ENGAGING")
	assert_null(attacker._engage_target, "move_to should clear engage target")


func test_attack_move_cancels_engage() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	attacker.engage_unit(enemy)
	attacker.attack_move_to(Vector2(200, 0))
	assert_eq(
		attacker._state,
		UnitBase.UnitState.ATTACK_MOVING,
		"attack_move should override ENGAGING",
	)
	assert_null(attacker._engage_target, "attack_move should clear engage target")


# --- Animation ---


func test_engaging_unit_plays_walk_animation() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	attacker.engage_unit(enemy)
	assert_true(attacker._is_moving, "ENGAGING should count as moving")
