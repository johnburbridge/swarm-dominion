class_name SpawnPanel extends Control
## HUD command panel: shows a spawn button while a Mother is selected, greys it
## out when the owning team can't afford a Drone, spawns on click, and offers a
## "Set Rally" button that requests rally-placement arming (SPI-1424), plus a
## "Clear Rally" button shown only while the tracked Mother actually has one to
## clear (SPI-1453).

signal rally_set_requested
signal rally_clear_requested

var _mother: MotherUnit = null

@onready var _button: Button = $SpawnButton
@onready var _rally_button: Button = $RallyButton
@onready var _clear_rally_button: Button = $ClearRallyButton


func _ready() -> void:
	visible = false
	_button.pressed.connect(_on_spawn_pressed)
	_rally_button.pressed.connect(_on_rally_pressed)
	_clear_rally_button.pressed.connect(_on_clear_rally_pressed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.mother_rally_changed.connect(_on_mother_rally_changed)


func _on_selection_changed(selected_units: Array[UnitBase]) -> void:
	_mother = _first_mother(selected_units)
	if _mother == null:
		visible = false
		return
	visible = true
	_refresh()


func _on_resources_changed(team_id: int, _amount: int) -> void:
	if visible and is_instance_valid(_mother) and team_id == _mother.team_id:
		_refresh()


func _on_spawn_pressed() -> void:
	if is_instance_valid(_mother):
		_mother.spawn_unit()


func _on_rally_pressed() -> void:
	rally_set_requested.emit()


func _on_clear_rally_pressed() -> void:
	rally_clear_requested.emit()


## A rally is normally placed by a map click, which produces no selection change,
## so the clear button's visibility has to react to the rally itself. Scoped to the
## tracked Mother — another Mother's rally must not drive this panel.
func _on_mother_rally_changed(mother: Node) -> void:
	if is_instance_valid(_mother) and mother == _mother:
		_refresh()


func _refresh() -> void:
	var cost := _mother.get_spawn_cost()
	_button.text = "Spawn Drone (%d)" % cost
	_button.disabled = not ResourceManager.can_afford(_mother.team_id, cost)
	_clear_rally_button.visible = _mother.has_rally()


func _first_mother(units: Array[UnitBase]) -> MotherUnit:
	for unit in units:
		if unit is MotherUnit:
			return unit
	return null
