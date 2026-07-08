class_name ResourceCounter extends Control
## HUD element showing the player's current biomass total.
## Updates live from EventBus.resources_changed.

const PLAYER_TEAM_ID: int = 1

@onready var _label: Label = $Label


func _ready() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)
	_update_display(ResourceManager.get_resources(PLAYER_TEAM_ID))


func _on_resources_changed(player_id: int, new_amount: int) -> void:
	if player_id == PLAYER_TEAM_ID:
		_update_display(new_amount)


func _update_display(amount: int) -> void:
	_label.text = "Biomass: %d" % amount
