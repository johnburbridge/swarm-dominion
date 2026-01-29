extends GutTest
## Tests for HealthBar UI component (SPI-1363).

var _unit: UnitBase
var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func before_each() -> void:
	_unit = _drone_scene.instantiate() as UnitBase
	add_child_autofree(_unit)
	await get_tree().process_frame


func test_health_bar_exists_as_child() -> void:
	var bar := _unit.get_node_or_null("HealthBar")
	assert_not_null(bar, "Drone should have a HealthBar child node")


func test_health_bar_has_background_and_fill() -> void:
	var bar := _unit.get_node("HealthBar")
	assert_not_null(bar.get_node_or_null("Background"), "HealthBar should have Background child")
	assert_not_null(bar.get_node_or_null("Fill"), "HealthBar should have Fill child")


func test_fill_starts_at_full_width() -> void:
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.size.x, HealthBar.BAR_WIDTH, "Fill should start at full width")


func test_fill_width_decreases_on_damage() -> void:
	_unit.take_damage(25)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	var expected_width: float = HealthBar.BAR_WIDTH * (25.0 / 50.0)
	assert_almost_eq(
		fill.size.x, expected_width, 0.01, "Fill width should be 50% after half damage"
	)


func test_fill_width_zero_at_zero_health() -> void:
	_unit.take_damage(50)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_almost_eq(fill.size.x, 0.0, 0.01, "Fill width should be 0 at zero health")


func test_color_green_at_full_health() -> void:
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_GREEN, "Color should be green at 100% health")


func test_color_lime_at_99_percent() -> void:
	_unit.take_damage(1)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_LIME, "Color should be lime at 99% health")


func test_color_lime_at_75_percent() -> void:
	_unit.take_damage(13)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_LIME, "Color should be lime at 75% health")


func test_color_yellow_below_75_percent() -> void:
	_unit.take_damage(14)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_YELLOW, "Color should be yellow below 75% health")


func test_color_yellow_above_50_percent() -> void:
	_unit.take_damage(24)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_YELLOW, "Color should be yellow above 50% health")


func test_color_orange_at_50_percent() -> void:
	_unit.take_damage(25)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_ORANGE, "Color should be orange at 50% health")


func test_color_orange_above_25_percent() -> void:
	_unit.take_damage(37)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_ORANGE, "Color should be orange above 25% health")


func test_color_red_at_25_percent() -> void:
	_unit.take_damage(38)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_RED, "Color should be red at 25% health or below")


func test_color_red_below_25_percent() -> void:
	_unit.take_damage(45)
	var fill: ColorRect = _unit.get_node("HealthBar/Fill")
	assert_eq(fill.color, HealthBar.COLOR_RED, "Color should be red below 25% health")


func test_bar_positioned_above_sprite() -> void:
	var bar: Control = _unit.get_node("HealthBar")
	assert_lt(bar.offset_top, 0.0, "Health bar should be above the unit (negative Y)")


func test_bar_centered_horizontally() -> void:
	var bar: Control = _unit.get_node("HealthBar")
	assert_almost_eq(
		bar.offset_left,
		-HealthBar.BAR_WIDTH / 2.0,
		0.01,
		"Health bar should be centered horizontally"
	)


func test_bar_visible_at_full_health() -> void:
	var bar: Control = _unit.get_node("HealthBar")
	assert_true(bar.visible, "Health bar should be visible at full health")


func test_background_width_unchanged_on_damage() -> void:
	var bg: ColorRect = _unit.get_node("HealthBar/Background")
	var initial_width := bg.size.x
	_unit.take_damage(25)
	assert_eq(bg.size.x, initial_width, "Background width should not change on damage")
