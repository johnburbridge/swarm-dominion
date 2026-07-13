extends GutTest
## Tests for the SpawnPanel HUD component (SPI-1423): a spawn button that appears
## while a Mother is selected, shows the data-driven Drone cost, greys out when the
## owning team can't afford one, and calls spawn_unit() on click.
##
## NOTE: load scenes by STRING PATH and never reference the `SpawnPanel` class as a
## type — at RED the script/scene don't exist, and referencing the type would make
## this file fail to PARSE (GUT silently skips an unparseable file — a false green).

const PLAYER_TEAM: int = 1

var _panel_scene: PackedScene
var _mother_scene: PackedScene
var _drone_scene: PackedScene
var _main_scene: PackedScene


func before_all() -> void:
	_panel_scene = load("res://scenes/ui/spawn_panel.tscn")
	_mother_scene = load("res://scenes/units/mother.tscn")
	_drone_scene = load("res://scenes/units/drone.tscn")
	_main_scene = load("res://scenes/main/main.tscn")


func before_each() -> void:
	ResourceManager.reset()
	SelectionManager.deselect_all()


func after_each() -> void:
	SelectionManager.deselect_all()


func _instantiate_panel() -> Control:
	var panel := _panel_scene.instantiate() as Control
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel


func _make_mother(tid: int) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = Vector2(400, 300)
	add_child_autofree(mother)
	return mother


func _make_drone(tid: int) -> UnitBase:
	var drone := _drone_scene.instantiate() as UnitBase
	drone.team_id = tid
	add_child_autofree(drone)
	return drone


func _count_player_drones() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("units"):
		if node is UnitBase and node.team_id == PLAYER_TEAM and node.unit_type == "drone":
			count += 1
	return count


func _free_spawned_drones() -> void:
	for node in get_tree().get_nodes_in_group("units"):
		if node is UnitBase and node.unit_type == "drone":
			node.queue_free()


# --- structure & visibility ---


func test_panel_has_spawn_button() -> void:
	var panel := await _instantiate_panel()
	assert_not_null(
		panel.get_node_or_null("SpawnButton"),
		"SpawnPanel should have a Button child named 'SpawnButton'"
	)


func test_hidden_when_nothing_selected() -> void:
	var panel := await _instantiate_panel()
	assert_false(panel.visible, "panel should be hidden with no selection")


func test_hidden_when_non_mother_selected() -> void:
	var panel := await _instantiate_panel()
	var drone := _make_drone(PLAYER_TEAM)
	SelectionManager.select_unit(drone)
	assert_false(panel.visible, "panel should stay hidden when only a Drone is selected")


func test_visible_when_mother_selected() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	assert_true(panel.visible, "panel should be visible when a Mother is selected")


func test_hidden_again_after_deselect() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	assert_true(panel.visible, "panel visible after selecting Mother")
	SelectionManager.deselect_all()
	assert_false(panel.visible, "panel should hide after deselect")


func test_mixed_selection_tracks_the_mother() -> void:
	var panel := await _instantiate_panel()
	var drone := _make_drone(PLAYER_TEAM)
	var mother := _make_mother(PLAYER_TEAM)
	ResourceManager.add_resources(PLAYER_TEAM, 100)
	var mixed: Array[UnitBase] = [drone, mother]
	SelectionManager.select_units(mixed)
	assert_true(panel.visible, "panel should be visible when a Mother is among the selection")
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button != null:
		assert_eq(
			button.text,
			"Spawn Drone (%d)" % mother.get_spawn_cost(),
			"panel should track the Mother's cost even in a mixed selection"
		)


# --- cost display ---


func test_button_shows_data_driven_cost() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button != null:
		assert_eq(
			button.text,
			"Spawn Drone (%d)" % mother.get_spawn_cost(),
			"button should show the data-driven Drone cost"
		)


# --- affordability & spawn ---


func test_affordable_enables_and_click_spawns() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	ResourceManager.add_resources(PLAYER_TEAM, 100)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button == null:
		return
	assert_false(button.disabled, "button should be enabled when affordable")
	var before_biomass := ResourceManager.get_resources(PLAYER_TEAM)
	var before_drones := _count_player_drones()
	button.pressed.emit()
	assert_eq(_count_player_drones(), before_drones + 1, "clicking should produce a Drone")
	assert_eq(
		ResourceManager.get_resources(PLAYER_TEAM),
		before_biomass - mother.get_spawn_cost(),
		"clicking should spend the spawn cost"
	)
	_free_spawned_drones()


func test_unaffordable_disables_and_no_spawn() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	# team has 0 biomass (reset in before_each)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button == null:
		return
	assert_true(button.disabled, "button should be disabled when unaffordable")
	var units_before := get_tree().get_nodes_in_group("units").size()
	button.pressed.emit()  # even if forced, spawn_unit() self-guards
	assert_eq(ResourceManager.get_resources(PLAYER_TEAM), 0, "no biomass spent when unaffordable")
	assert_eq(
		get_tree().get_nodes_in_group("units").size(),
		units_before,
		"no Drone produced when unaffordable"
	)


func test_button_enables_live_when_biomass_added() -> void:
	var panel := await _instantiate_panel()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	var button := panel.get_node_or_null("SpawnButton") as Button
	assert_not_null(button, "SpawnButton should exist")
	if button == null:
		return
	assert_true(button.disabled, "button starts disabled (0 biomass)")
	ResourceManager.add_resources(PLAYER_TEAM, mother.get_spawn_cost())
	assert_false(button.disabled, "button should enable live once affordable")


# --- accessor ---


func test_mother_get_spawn_cost_returns_loaded_cost() -> void:
	var mother := _make_mother(PLAYER_TEAM)
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var expected := int(json.data["spawn_costs"]["drone"]["biomass"])
	assert_eq(mother.get_spawn_cost(), expected, "get_spawn_cost should return the loaded cost")


func test_main_scene_has_spawn_panel_under_ui_hidden() -> void:
	var main := _main_scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("UI/SpawnPanel") as Control
	assert_not_null(panel, "main.tscn should have a SpawnPanel at UI/SpawnPanel")
	if panel != null:
		assert_false(panel.visible, "SpawnPanel should be hidden on load (no selection)")
