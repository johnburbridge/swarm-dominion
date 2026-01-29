extends GutTest
## Tests for UnitBase auto-attack behavior (SPI-1364).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


# -- Detection range (AC1) --


func test_attack_range_loaded_from_stats() -> void:
	var unit := _create_unit(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(unit.attack_range, 80.0, "attack_range should be 80 from unit_stats.json")


func test_attack_area_created() -> void:
	var unit := _create_unit(1, Vector2.ZERO)
	await get_tree().process_frame
	var area := unit.get_node_or_null("AttackRange")
	assert_not_null(area, "Drone should have an AttackRange child")
	assert_true(area is Area2D, "AttackRange should be an Area2D")


func test_enemy_detected_in_range() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(
		enemy in attacker._enemies_in_range, "Enemy within 80px should be in _enemies_in_range"
	)


func test_friendly_not_detected() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(
		unit_b in unit_a._enemies_in_range, "Same-team unit should not be in _enemies_in_range"
	)


# -- Auto-attack nearest (AC2) --


func test_idle_unit_attacks_enemy_in_range() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Process one more frame so _try_acquire_target runs
	await get_tree().physics_frame
	assert_eq(attacker._attack_target, enemy, "Idle unit should acquire enemy as attack target")


func test_targets_nearest_enemy() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var far_enemy := _create_unit(2, Vector2(70, 0))
	var near_enemy := _create_unit(2, Vector2(30, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(attacker._attack_target, near_enemy, "Should target the nearest enemy")


func test_retargets_when_target_dies() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy1 := _create_unit(2, Vector2(30, 0))
	var enemy2 := _create_unit(2, Vector2(60, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(attacker._attack_target, enemy1, "Should target nearest first")
	# Kill enemy1 via signal
	enemy1.take_damage(999)
	# Allow retarget
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(attacker._attack_target, enemy2, "Should retarget to remaining enemy")


# -- Attack timing (AC3) --


func test_attack_deals_damage() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Allow attack to happen (cooldown starts at 0 = immediate)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_lt(enemy.current_health, enemy.max_health, "Enemy should have taken damage")


func test_damage_matches_stat() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var initial_health := enemy.current_health
	# Allow one attack cycle
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		enemy.current_health,
		initial_health - attacker.damage,
		"Damage dealt should match attacker's damage stat"
	)


func test_unit_attacked_signal_emitted() -> void:
	watch_signals(EventBus)
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_signal_emitted(EventBus, "unit_attacked")


# -- Facing target (AC4) --


func test_faces_right_for_right_enemy() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sprite: AnimatedSprite2D = attacker.get_node("AnimatedSprite2D")
	assert_false(sprite.flip_h, "flip_h should be false when enemy is to the right")


func test_faces_left_for_left_enemy() -> void:
	var attacker := _create_unit(1, Vector2(50, 0))
	var enemy := _create_unit(2, Vector2(0, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sprite: AnimatedSprite2D = attacker.get_node("AnimatedSprite2D")
	assert_true(sprite.flip_h, "flip_h should be true when enemy is to the left")


# -- Stop attacking (AC5) --


func test_returns_to_idle_when_enemy_dies() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(attacker._attack_target, enemy)
	# Kill enemy
	enemy.take_damage(999)
	await get_tree().physics_frame
	assert_null(attacker._attack_target, "attack_target should be null after target dies")


func test_attack_stopped_signal_emitted() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	watch_signals(attacker)
	# Kill enemy to trigger attack_stopped
	enemy.take_damage(999)
	await get_tree().physics_frame
	assert_signal_emitted(attacker, "attack_stopped")


# -- Movement interrupts (AC6) --


func test_move_command_clears_target() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_not_null(attacker._attack_target, "Should have a target before move")
	attacker.move_to(Vector2(500, 0))
	assert_null(attacker._attack_target, "move_to should clear attack target")
	assert_true(attacker._is_moving, "Unit should be moving after move_to")


func test_moving_unit_does_not_engage() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	attacker.move_to(Vector2(500, 0))
	await get_tree().process_frame
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(attacker._is_moving, "Unit should still be moving")
	assert_null(attacker._attack_target, "Moving unit should not acquire attack target")


# -- Team affiliation (AC7/10) --


func test_same_team_not_attacked() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_null(unit_a._attack_target, "Should not target same-team unit")


func test_different_team_attacked() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(attacker._attack_target, enemy, "Should target different-team unit")


# -- Edge cases --


func test_dead_unit_does_not_attack() -> void:
	var attacker := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(50, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Kill attacker
	attacker.take_damage(999)
	await get_tree().physics_frame
	var enemy_health := enemy.current_health
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(enemy.current_health, enemy_health, "Dead unit should not deal damage")


func test_no_attack_area_when_range_zero() -> void:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.unit_type = "mother"
	add_child_autofree(unit)
	await get_tree().process_frame
	var area := unit.get_node_or_null("AttackRange")
	assert_null(area, "Unit with 0 attack_range should have no AttackRange child")
