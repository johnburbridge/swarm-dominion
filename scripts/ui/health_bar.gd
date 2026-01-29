class_name HealthBar extends Control

const BAR_WIDTH: float = 24.0
const BAR_HEIGHT: float = 4.0
const COLOR_GREEN: Color = Color(0.2, 0.8, 0.2)
const COLOR_LIME: Color = Color(0.6, 0.8, 0.1)
const COLOR_YELLOW: Color = Color(0.9, 0.8, 0.1)
const COLOR_ORANGE: Color = Color(0.9, 0.5, 0.1)
const COLOR_RED: Color = Color(0.8, 0.1, 0.1)

@onready var _background: ColorRect = $Background
@onready var _fill: ColorRect = $Fill


func _ready() -> void:
	var parent := get_parent()
	if parent.has_signal("health_changed"):
		parent.health_changed.connect(_on_health_changed)


func _on_health_changed(current_health: int, max_health: int) -> void:
	if max_health <= 0:
		return
	var ratio: float = float(current_health) / float(max_health)
	_fill.size.x = BAR_WIDTH * ratio
	_fill.color = _get_color_for_ratio(ratio)


func _get_color_for_ratio(ratio: float) -> Color:
	if ratio >= 1.0:
		return COLOR_GREEN
	if ratio >= 0.75:
		return COLOR_LIME
	if ratio > 0.5:
		return COLOR_YELLOW
	if ratio > 0.25:
		return COLOR_ORANGE
	return COLOR_RED
