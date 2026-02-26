extends Node
## Manages unit selection state.

signal selection_changed(selected_units: Array[UnitBase])

const GROUP_COUNT: int = 5

var _selected_units: Array[UnitBase] = []
var _control_groups: Array[Array] = [[], [], [], [], []]


func get_selected_units() -> Array[UnitBase]:
	return _selected_units


func select_unit(unit: UnitBase) -> void:
	if unit in _selected_units:
		return
	deselect_all()
	_selected_units.append(unit)
	unit.set_selected(true)
	selection_changed.emit(_selected_units)


func select_units(units: Array[UnitBase]) -> void:
	deselect_all()
	for unit in units:
		if is_instance_valid(unit) and unit not in _selected_units:
			_selected_units.append(unit)
			unit.set_selected(true)
	selection_changed.emit(_selected_units)


func deselect_all() -> void:
	for unit in _selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	_selected_units.clear()
	selection_changed.emit(_selected_units)


func remove_unit(unit: UnitBase) -> void:
	if unit in _selected_units:
		_selected_units.erase(unit)
		selection_changed.emit(_selected_units)
	for group in _control_groups:
		group.erase(unit)


func assign_group(index: int) -> void:
	if index < 0 or index >= GROUP_COUNT:
		return
	_control_groups[index] = _selected_units.duplicate()


func recall_group(index: int) -> void:
	if index < 0 or index >= GROUP_COUNT:
		return
	var valid_units: Array[UnitBase] = []
	for unit in _control_groups[index]:
		if is_instance_valid(unit) and not unit._is_dead:
			valid_units.append(unit)
	_control_groups[index].assign(valid_units)
	select_units(valid_units)


func clear_all_groups() -> void:
	for i in range(GROUP_COUNT):
		_control_groups[i] = []
