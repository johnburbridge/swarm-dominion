class_name SpawnPanel extends Control
## HUD command panel: shows a spawn button while a Mother is selected, greys it
## out when the owning team can't afford a Drone, and spawns on click.

var _mother: MotherUnit = null

@onready var _button: Button = $SpawnButton


func _ready() -> void:
	visible = false
	_button.pressed.connect(_on_spawn_pressed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	EventBus.resources_changed.connect(_on_resources_changed)


func _on_selection_changed(selected_units: Array[UnitBase]) -> void:
	_mother = _first_mother(selected_units)
	if _mother == null:
		visible = false
		return
	visible = true
	_refresh()


func _on_resources_changed(team_id: int, _amount: int) -> void:
	if visible and _mother != null and team_id == _mother.team_id:
		_refresh()


func _on_spawn_pressed() -> void:
	if is_instance_valid(_mother):
		_mother.spawn_unit()


func _refresh() -> void:
	var cost := _mother.get_spawn_cost()
	_button.text = "Spawn Drone (%d)" % cost
	_button.disabled = not ResourceManager.can_afford(_mother.team_id, cost)


func _first_mother(units: Array[UnitBase]) -> MotherUnit:
	for unit in units:
		if unit is MotherUnit:
			return unit
	return null
