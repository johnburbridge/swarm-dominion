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


# --- Harvest (SPI-1385) ---


func test_harvest_extracts_requested_amount_from_full_node() -> void:
	var node := _create_node()
	await get_tree().process_frame
	var extracted := node.harvest(30)
	assert_eq(extracted, 30, "should extract the requested amount")
	assert_eq(node.current_biomass, 70, "should decrement current_biomass by amount")


func test_harvest_clamps_to_remaining_biomass() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.current_biomass = 20
	var extracted := node.harvest(50)
	assert_eq(extracted, 20, "should return only the remaining amount")
	assert_eq(node.current_biomass, 0, "should leave current_biomass at 0")


func test_harvest_emits_biomass_changed_with_params() -> void:
	var node := _create_node()
	await get_tree().process_frame
	watch_signals(node)
	node.harvest(25)
	assert_signal_emitted_with_parameters(node, "biomass_changed", [75, 100])


func test_harvest_that_empties_node_emits_depleted() -> void:
	var node := _create_node()
	await get_tree().process_frame
	watch_signals(node)
	node.harvest(100)
	assert_signal_emitted(node, "biomass_depleted")


func test_harvest_zero_returns_zero_and_emits_nothing() -> void:
	var node := _create_node()
	await get_tree().process_frame
	watch_signals(node)
	var extracted := node.harvest(0)
	assert_eq(extracted, 0, "harvest(0) should return 0")
	assert_signal_not_emitted(node, "biomass_changed")
	assert_signal_not_emitted(node, "biomass_depleted")


func test_harvest_on_depleted_node_returns_zero() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.current_biomass = 0
	var extracted := node.harvest(10)
	assert_eq(extracted, 0, "harvesting a depleted node should return 0")


# --- Regeneration (SPI-1388) ---


func test_no_regen_before_delay_elapses() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40, resets regen countdown, enables processing
	for _i in range(5):  # ~0.083s elapsed, still < 0.2s delay
		await get_tree().physics_frame
	assert_eq(node.current_biomass, 40, "should not regrow before regen_delay elapses")


func test_regen_after_delay() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40
	for _i in range(40):  # ~0.67s elapsed, well past 0.2s delay
		await get_tree().physics_frame
	assert_gt(node.current_biomass, 40, "should regrow after regen_delay elapses")


func test_regen_caps_at_max() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 100000.0
	node.harvest(90)  # current 10
	for _i in range(60):
		await get_tree().physics_frame
	assert_eq(node.current_biomass, node.max_biomass, "regrowth should cap at max_biomass")


func test_partial_node_recovers() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(50)  # current 50 (partial, never emptied)
	for _i in range(40):
		await get_tree().physics_frame
	assert_gt(node.current_biomass, 50, "a partially-drained node should recover")


func test_harvest_resets_regen_countdown() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.3
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40, t=0
	for _i in range(10):  # ~0.167s, still < 0.3s
		await get_tree().physics_frame
	node.harvest(5)  # current 35, resets t back to 0
	var after_second_harvest := node.current_biomass
	for _i in range(10):  # another ~0.167s; total since 2nd harvest < 0.3s
		await get_tree().physics_frame
	assert_eq(
		node.current_biomass,
		after_second_harvest,
		"a fresh harvest should reset the regen countdown (no premature regrowth)",
	)


func test_regen_emits_fully_regenerated_at_max() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 100000.0
	node.harvest(50)  # current 50
	watch_signals(node)
	for _i in range(60):
		await get_tree().physics_frame
	assert_eq(node.current_biomass, node.max_biomass, "precondition: node back to max")
	assert_signal_emitted(node, "fully_regenerated")


func test_regen_emits_biomass_changed() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40
	watch_signals(node)
	for _i in range(40):
		await get_tree().physics_frame
	assert_signal_emitted(node, "biomass_changed")


func test_depleted_node_regenerates_and_is_harvestable_again() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(100)  # fully depleted
	assert_true(node.is_depleted(), "precondition: node depleted")
	for _i in range(40):
		await get_tree().physics_frame
	assert_false(node.is_depleted(), "regrown node should no longer be depleted (AC5)")
