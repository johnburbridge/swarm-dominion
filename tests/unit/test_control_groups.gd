extends GutTest
## Tests for control group behavior (SPI-1372).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


func before_each() -> void:
	SelectionManager.deselect_all()
	SelectionManager.clear_all_groups()


func test_assign_and_recall_group() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(100, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a, unit_b] as Array[UnitBase])
	SelectionManager.assign_group(0)
	# Deselect, then recall
	SelectionManager.deselect_all()
	assert_eq(SelectionManager.get_selected_units().size(), 0, "should be deselected")
	SelectionManager.recall_group(0)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 2, "recall should restore 2 units")
	assert_has(selected, unit_a, "should contain unit_a")
	assert_has(selected, unit_b, "should contain unit_b")


func test_assign_replaces_previous_group() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	var unit_b := _create_unit(1, Vector2(100, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a] as Array[UnitBase])
	SelectionManager.assign_group(0)
	# Reassign with different unit
	SelectionManager.select_units([unit_b] as Array[UnitBase])
	SelectionManager.assign_group(0)
	SelectionManager.deselect_all()
	SelectionManager.recall_group(0)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 1, "group should have 1 unit after reassign")
	assert_eq(selected[0], unit_b, "should be unit_b after reassign")


func test_recall_empty_group_does_nothing() -> void:
	var unit_a := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	SelectionManager.select_units([unit_a] as Array[UnitBase])
	# Recall an unassigned group
	SelectionManager.recall_group(3)
	var selected := SelectionManager.get_selected_units()
	assert_eq(selected.size(), 0, "recall empty group should deselect all")
