extends GutTest
## Tests for UnitBase death visuals and cleanup (SPI-1365).

var _unit: UnitBase
var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	_unit = _drone_scene.instantiate() as UnitBase
	add_child_autofree(_unit)
	await get_tree().process_frame


func test_death_plays_death_animation() -> void:
	_unit.take_damage(_unit.max_health)
	assert_eq(
		_unit._sprite.animation,
		&"death",
		"sprite should switch to 'death' animation on lethal damage"
	)


func test_death_starts_fade_out() -> void:
	assert_eq(_unit.modulate.a, 1.0, "modulate.a should start at 1.0")
	_unit.take_damage(_unit.max_health)
	# Advance partway through the 0.5s fade tween
	await get_tree().create_timer(0.3).timeout
	assert_lt(_unit.modulate.a, 1.0, "modulate.a should decrease during fade-out tween")


func test_death_disables_attack_collision() -> void:
	_unit.take_damage(_unit.max_health)
	# set_deferred runs next frame
	await get_tree().process_frame
	var attack_area: Area2D = _unit._attack_area
	assert_not_null(attack_area, "unit should have an AttackRange area")
	var shape_node := attack_area.get_child(0) as CollisionShape2D
	assert_true(shape_node.disabled, "AttackRange collision shape should be disabled after death")


func test_dead_unit_is_invalid_target() -> void:
	_unit.take_damage(_unit.max_health)
	assert_false(
		_unit._is_valid_target(_unit), "_is_valid_target should return false for a dead unit"
	)
