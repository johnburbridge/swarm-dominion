extends GutTest
## Tests for HarvestIndicator UI component (SPI-1387).
## A static biomass-green pip that appears above a unit ONLY while it is in
## the HARVESTING state, disappearing when harvesting stops (command change,
## node depletion, or death).

## Expected biomass-green pip color. The GREEN phase must match this literal
## on the HarvestIndicator class (e.g. `const COLOR_HARVEST`). Defined locally
## because the HarvestIndicator class_name does not exist yet.
const COLOR_HARVEST_EXPECTED: Color = Color(0.3, 0.9, 0.2)

var _drone_scene: PackedScene
var _node_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")
	_node_scene = load("res://scenes/resources/biomass_node.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _create_unit(tid: int, pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	unit.position = pos
	add_child_autofree(unit)
	return unit


func _create_node(pos: Vector2) -> BiomassNode:
	var node := _node_scene.instantiate() as BiomassNode
	node.position = pos
	add_child_autofree(node)
	return node


# --- is_harvesting() public API ---


func test_is_harvesting_true_after_harvest_at() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	assert_true(unit.is_harvesting(), "is_harvesting() should be true right after harvest_at")


func test_is_harvesting_false_when_idle() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	assert_false(unit.is_harvesting(), "is_harvesting() should be false when IDLE")


# --- Scenario 1: shows feedback while harvesting ---


func test_indicator_exists_as_child() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")


func test_indicator_has_pip_child() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	var pip := indicator.get_node_or_null("Pip")
	assert_not_null(pip, "HarvestIndicator should have a Pip ColorRect child")
	assert_true(pip is ColorRect, "Pip should be a ColorRect")


func test_indicator_visible_while_harvesting() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	await get_tree().process_frame
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	assert_true(indicator.visible, "indicator should be visible while HARVESTING")


func test_pip_color_is_biomass_green() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	var pip := indicator.get_node_or_null("Pip")
	assert_not_null(pip, "HarvestIndicator should have a Pip ColorRect child")
	assert_eq(pip.color, COLOR_HARVEST_EXPECTED, "Pip should be the biomass-green color")


# --- Scenario 2: disappears on stop ---


func test_indicator_hidden_initially_when_idle() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	assert_false(indicator.visible, "indicator should start hidden while IDLE")


func test_indicator_hidden_after_move_cancels_harvest() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	await get_tree().process_frame
	unit.move_to(Vector2(400, 0))
	await get_tree().process_frame
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	assert_false(indicator.visible, "indicator should be hidden after move_to cancels harvesting")


func test_indicator_hidden_after_node_depletes() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	node.harvest(node.max_biomass - 3)
	unit.harvest_speed = 5
	unit.harvest_at(node)
	for _i in range(90):
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(node.is_depleted(), "precondition: node should be depleted")
	assert_false(unit.is_harvesting(), "unit should no longer be harvesting after depletion")
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	assert_false(indicator.visible, "indicator should be hidden after the node depletes")


func test_indicator_hidden_when_dead() -> void:
	var node := _create_node(Vector2(0, 0))
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.harvest_at(node)
	await get_tree().process_frame
	unit.take_damage(unit.max_health)
	await get_tree().process_frame
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	assert_false(indicator.visible, "indicator should be hidden when the unit is DEAD")


# --- Scenario 3: distinguishable from combat ---


func test_indicator_hidden_while_engaging() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	var enemy := _create_unit(2, Vector2(500, 0))
	await get_tree().process_frame
	unit.engage_unit(enemy)
	await get_tree().process_frame
	assert_false(unit.is_harvesting(), "engaging unit should not be harvesting")
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	assert_false(indicator.visible, "indicator should be hidden while ENGAGING")


func test_indicator_hidden_while_moving() -> void:
	var unit := _create_unit(1, Vector2(0, 0))
	await get_tree().process_frame
	unit.move_to(Vector2(400, 0))
	await get_tree().process_frame
	assert_false(unit.is_harvesting(), "moving unit should not be harvesting")
	var indicator := unit.get_node_or_null("HarvestIndicator")
	assert_not_null(indicator, "Drone should have a HarvestIndicator child node")
	assert_false(indicator.visible, "indicator should be hidden while MOVING")
