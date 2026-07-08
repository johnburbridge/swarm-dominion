class_name HarvestIndicator extends Control
## Shows a biomass-green pip above a unit while it is harvesting (SPI-1387).

var _unit: Node = null


func _ready() -> void:
	_unit = get_parent()
	visible = false


func _process(_delta: float) -> void:
	if _unit != null and _unit.has_method("is_harvesting"):
		visible = _unit.is_harvesting()
	else:
		visible = false
