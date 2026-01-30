extends GutTest
## Tests for unit selection visual and behavior (SPI-1368).

var _unit: UnitBase
var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	SelectionManager.deselect_all()
	_unit = _drone_scene.instantiate() as UnitBase
	_unit.team_id = 1
	add_child_autofree(_unit)
	await get_tree().process_frame


func test_set_selected_true_shows_circle() -> void:
	_unit.set_selected(true)
	assert_true(
		_unit._selection_circle.visible,
		"selection circle should be visible after set_selected(true)"
	)


func test_set_selected_false_hides_circle() -> void:
	_unit.set_selected(true)
	_unit.set_selected(false)
	assert_false(
		_unit._selection_circle.visible,
		"selection circle should be hidden after set_selected(false)"
	)


func test_death_removes_from_selection() -> void:
	SelectionManager.select_unit(_unit)
	assert_eq(SelectionManager.get_selected_units().size(), 1, "unit should be selected")
	_unit.take_damage(_unit.max_health)
	assert_eq(
		SelectionManager.get_selected_units().size(),
		0,
		"selection should be empty after unit death"
	)


func test_set_selected_emits_events() -> void:
	watch_signals(EventBus)
	_unit.set_selected(true)
	assert_signal_emitted(EventBus, "unit_selected")
	_unit.set_selected(false)
	assert_signal_emitted(EventBus, "unit_deselected")
