extends GutTest
## Tests for UnitBase health, damage, and death mechanics (SPI-1362).

var _unit: UnitBase
var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	_unit = _drone_scene.instantiate() as UnitBase
	add_child_autofree(_unit)
	# Allow _ready() to complete
	await get_tree().process_frame


func test_stats_loaded_from_json() -> void:
	assert_eq(_unit.max_health, 50, "max_health should be 50 from unit_stats.json")
	assert_eq(_unit.current_health, 50, "current_health should equal max_health")
	assert_eq(_unit.damage, 10, "damage should be 10 from unit_stats.json")
	assert_eq(_unit.attack_speed, 1.0, "attack_speed should be 1.0 from unit_stats.json")
	assert_eq(_unit.move_speed, 150.0, "move_speed should be 150 from unit_stats.json")


func test_default_team_id() -> void:
	assert_eq(_unit.team_id, 0, "team_id should default to 0")


func test_team_id_can_be_set() -> void:
	_unit.team_id = 2
	assert_eq(_unit.team_id, 2, "team_id should be settable")


func test_default_unit_type() -> void:
	assert_eq(_unit.unit_type, "drone", "unit_type should default to 'drone'")


func test_take_damage_reduces_health() -> void:
	_unit.take_damage(10)
	assert_eq(_unit.current_health, 40, "health should decrease by damage amount")


func test_take_damage_emits_health_changed() -> void:
	watch_signals(_unit)
	_unit.take_damage(10)
	assert_signal_emitted(_unit, "health_changed")
	assert_signal_emitted_with_parameters(_unit, "health_changed", [40, 50])


func test_health_clamps_at_zero() -> void:
	_unit.take_damage(999)
	assert_eq(_unit.current_health, 0, "health should clamp at 0, not go negative")


func test_death_at_zero_hp_sets_is_dead() -> void:
	_unit.take_damage(50)
	assert_true(_unit._is_dead, "_is_dead should be true after lethal damage")


func test_death_removes_from_units_group() -> void:
	assert_true(_unit.is_in_group("units"), "unit should be in 'units' group initially")
	_unit.take_damage(50)
	assert_false(_unit.is_in_group("units"), "unit should be removed from 'units' group on death")


func test_death_emits_unit_died_on_event_bus() -> void:
	watch_signals(EventBus)
	_unit.take_damage(50)
	assert_signal_emitted(EventBus, "unit_died")


func test_dead_unit_ignores_further_damage() -> void:
	_unit.take_damage(50)
	assert_eq(_unit.current_health, 0)
	watch_signals(_unit)
	_unit.take_damage(10)
	assert_eq(_unit.current_health, 0, "dead unit health should remain at 0")
	assert_signal_not_emitted(_unit, "health_changed", "dead unit should not emit health_changed")


func test_dead_unit_ignores_move_commands() -> void:
	var start_pos := _unit.position
	_unit.take_damage(50)
	_unit.move_to(start_pos + Vector2(500, 500))
	assert_false(_unit._is_moving, "dead unit should not start moving after move_to()")
