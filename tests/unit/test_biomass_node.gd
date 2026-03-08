extends GutTest
## Tests for BiomassNode scene and script (SPI-1382).

var _node_scene: PackedScene


func before_all() -> void:
	_node_scene = load("res://scenes/resources/biomass_node.tscn")


func _create_node(pos: Vector2 = Vector2.ZERO) -> BiomassNode:
	var node := _node_scene.instantiate() as BiomassNode
	node.position = pos
	add_child_autofree(node)
	return node


# --- Initialization ---


func test_biomass_starts_at_max() -> void:
	var node := _create_node()
	await get_tree().process_frame
	assert_eq(node.current_biomass, node.max_biomass, "should start with full biomass")


func test_default_max_biomass() -> void:
	var node := _create_node()
	await get_tree().process_frame
	assert_eq(node.max_biomass, 100, "default max biomass should be 100")


func test_is_not_depleted_initially() -> void:
	var node := _create_node()
	await get_tree().process_frame
	assert_false(node.is_depleted(), "should not be depleted initially")


# --- Collision layer ---


func test_collision_layer_is_resource_layer() -> void:
	var node := _create_node()
	await get_tree().process_frame
	assert_eq(node.collision_layer, 4, "should be on layer 3 (bitmask 4)")
	assert_eq(node.collision_mask, 0, "should not collide with anything")


# --- HarvestArea ---


func test_harvest_area_exists() -> void:
	var node := _create_node()
	await get_tree().process_frame
	var area := node.get_node_or_null("HarvestArea")
	assert_not_null(area, "should have HarvestArea child")
	assert_true(area is Area2D, "HarvestArea should be Area2D")


func test_harvest_area_detects_units() -> void:
	var node := _create_node()
	await get_tree().process_frame
	var area := node.get_node("HarvestArea") as Area2D
	assert_eq(area.collision_mask, 1, "HarvestArea should detect layer 1 (units)")


# --- Export vars ---


func test_export_vars_configurable() -> void:
	var node := _create_node()
	node.max_biomass = 200
	node.regen_rate = 5.0
	node.regen_delay = 15.0
	node.harvest_radius = 60.0
	await get_tree().process_frame
	assert_eq(node.max_biomass, 200, "max_biomass should be configurable")
	assert_eq(node.regen_rate, 5.0, "regen_rate should be configurable")
	assert_eq(node.regen_delay, 15.0, "regen_delay should be configurable")
	assert_eq(node.harvest_radius, 60.0, "harvest_radius should be configurable")


# --- Depletion check ---


func test_is_depleted_when_zero() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.current_biomass = 0
	assert_true(node.is_depleted(), "should be depleted when biomass is 0")
