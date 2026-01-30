extends GutTest
## Tests for SelectionManager singleton (SPI-1368).

var _unit_a: UnitBase
var _unit_b: UnitBase
var _drone_scene: PackedScene
var _signal_watcher_node: Node


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	SelectionManager.deselect_all()
	_unit_a = _drone_scene.instantiate() as UnitBase
	_unit_a.team_id = 1
	add_child_autofree(_unit_a)
	_unit_b = _drone_scene.instantiate() as UnitBase
	_unit_b.team_id = 1
	add_child_autofree(_unit_b)
	await get_tree().process_frame


func test_select_unit_adds_to_selection() -> void:
	SelectionManager.select_unit(_unit_a)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 1, "should have one selected unit")
	assert_eq(selected[0], _unit_a, "selected unit should be unit_a")


func test_select_unit_emits_signal() -> void:
	watch_signals(SelectionManager)
	SelectionManager.select_unit(_unit_a)
	assert_signal_emitted(SelectionManager, "selection_changed")


func test_deselect_all_clears_selection() -> void:
	SelectionManager.select_unit(_unit_a)
	SelectionManager.deselect_all()
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 0, "selection should be empty after deselect_all")


func test_select_new_unit_deselects_previous() -> void:
	SelectionManager.select_unit(_unit_a)
	SelectionManager.select_unit(_unit_b)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 1, "should have exactly one selected unit")
	assert_eq(selected[0], _unit_b, "selected unit should be unit_b")
	assert_false(_unit_a._is_selected, "unit_a should be deselected")


func test_remove_unit_on_death() -> void:
	SelectionManager.select_unit(_unit_a)
	SelectionManager.remove_unit(_unit_a)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 0, "selection should be empty after remove_unit")
