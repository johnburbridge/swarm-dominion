class_name HarvestIndicator extends Control
## Shows a biomass-green pip above a unit while it is harvesting (SPI-1387).

const COLOR_HARVEST: Color = Color(0.3, 0.9, 0.2)

var _unit: Node = null

@onready var _pip: ColorRect = $Pip


func _ready() -> void:
	_unit = get_parent()
	_pip.color = COLOR_HARVEST
	visible = false
	# Only poll if the parent can actually report harvest state; non-harvesting
	# parents never run _process.
	set_process(_unit != null and _unit.has_method("is_harvesting"))


# Polls the unit's authoritative HARVESTING state each frame rather than reacting
# to a signal (as HealthBar does for health_changed): harvesting stops via several
# paths — a new command, node depletion, or death — with no single choke point, so
# reading is_harvesting() is more robust than emitting from every state-exit site.
func _process(_delta: float) -> void:
	visible = _unit.is_harvesting()
