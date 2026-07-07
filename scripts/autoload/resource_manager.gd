extends Node
## Tracks per-team biomass totals — the single ledger for gathered resources.
## Add, spend, and query biomass here; emits EventBus.resources_changed on change.

const STARTING_BIOMASS: int = 0

var _biomass: Dictionary = {}  # team_id: int -> biomass: int


func get_resources(team_id: int) -> int:
	return int(_biomass.get(team_id, STARTING_BIOMASS))


func can_afford(team_id: int, amount: int) -> bool:
	return get_resources(team_id) >= amount


func add_resources(team_id: int, amount: int) -> void:
	if amount <= 0:
		return
	var new_amount := get_resources(team_id) + amount
	_biomass[team_id] = new_amount
	EventBus.resources_changed.emit(team_id, new_amount)


func spend_resources(team_id: int, amount: int) -> bool:
	if amount <= 0:
		return false
	if not can_afford(team_id, amount):
		return false
	var new_amount := get_resources(team_id) - amount
	_biomass[team_id] = new_amount
	EventBus.resources_changed.emit(team_id, new_amount)
	return true


func reset() -> void:
	_biomass.clear()
