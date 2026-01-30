extends Node
## Manages unit selection state.

signal selection_changed(selected_units: Array[UnitBase])

var _selected_units: Array[UnitBase] = []


func get_selected_units() -> Array[UnitBase]:
	return _selected_units


func select_unit(unit: UnitBase) -> void:
	if unit in _selected_units:
		return
	deselect_all()
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
