extends GutTest
## Tests for the ResourceCounter HUD component (SPI-1384).
##
## The counter displays the player's biomass total and updates live via the
## EventBus.resources_changed signal.
##
## NOTE: We deliberately load the scene by STRING PATH and never reference the
## `ResourceCounter` class_name as a type. The production script/scene do not
## exist yet, so referencing the type would make this file fail to PARSE, which
## GUT silently skips (a false green). Loading by path fails loudly per-test
## instead, giving a clean RED.

const PLAYER_TEAM: int = 1
const ENEMY_TEAM: int = 2

var _counter_scene: PackedScene
var _main_scene: PackedScene


func before_all() -> void:
	_counter_scene = load("res://scenes/ui/resource_counter.tscn")
	_main_scene = load("res://scenes/main/main.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _instantiate_counter() -> Control:
	var counter := _counter_scene.instantiate() as Control
	add_child_autofree(counter)
	await get_tree().process_frame
	return counter


# --- AC1: structure ---


func test_counter_has_label_child() -> void:
	var counter := await _instantiate_counter()
	var label := counter.get_node_or_null("Label")
	assert_not_null(label, "ResourceCounter should have a Label child node named 'Label'")


# --- AC1: initializes to current amount on ready ---


func test_label_reads_zero_with_fresh_manager() -> void:
	var counter := await _instantiate_counter()
	var label := counter.get_node_or_null("Label")
	assert_not_null(label, "ResourceCounter should have a Label child")
	assert_eq(label.text, "Biomass: 0", "fresh counter should read 'Biomass: 0'")


func test_label_reflects_existing_amount_on_ready() -> void:
	ResourceManager.add_resources(PLAYER_TEAM, 25)
	var counter := await _instantiate_counter()
	var label := counter.get_node_or_null("Label")
	assert_not_null(label, "ResourceCounter should have a Label child")
	assert_eq(
		label.text, "Biomass: 25", "counter should show current amount (25) present before ready"
	)


# --- AC2: live updates on resources_changed ---


func test_label_updates_when_player_resources_change() -> void:
	var counter := await _instantiate_counter()
	var label := counter.get_node_or_null("Label")
	assert_not_null(label, "ResourceCounter should have a Label child")
	assert_eq(label.text, "Biomass: 0", "counter should start at 'Biomass: 0'")

	ResourceManager.add_resources(PLAYER_TEAM, 10)
	assert_eq(label.text, "Biomass: 10", "counter should update to 'Biomass: 10' after add")


func test_label_follows_decrease_on_spend() -> void:
	var counter := await _instantiate_counter()
	var label := counter.get_node_or_null("Label")
	assert_not_null(label, "ResourceCounter should have a Label child")

	ResourceManager.add_resources(PLAYER_TEAM, 50)
	assert_eq(label.text, "Biomass: 50", "counter should read 'Biomass: 50' after add")

	ResourceManager.spend_resources(PLAYER_TEAM, 20)
	assert_eq(
		label.text, "Biomass: 30", "counter should follow decrease to 'Biomass: 30' after spend"
	)


# --- AC3: ignores other teams ---


func test_label_ignores_enemy_team_changes() -> void:
	var counter := await _instantiate_counter()
	var label := counter.get_node_or_null("Label")
	assert_not_null(label, "ResourceCounter should have a Label child")

	ResourceManager.add_resources(ENEMY_TEAM, 10)
	assert_eq(label.text, "Biomass: 0", "enemy team changes should not affect the player counter")


func test_label_shows_only_player_amount_when_mixed() -> void:
	var counter := await _instantiate_counter()
	var label := counter.get_node_or_null("Label")
	assert_not_null(label, "ResourceCounter should have a Label child")

	ResourceManager.add_resources(PLAYER_TEAM, 10)
	ResourceManager.add_resources(ENEMY_TEAM, 99)
	assert_eq(label.text, "Biomass: 10", "counter should track only the player's team amount")


# --- AC4: wired into main.tscn under the UI CanvasLayer ---


func test_main_scene_has_resource_counter_under_ui() -> void:
	var main := _main_scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame

	var counter := main.get_node_or_null("UI/ResourceCounter")
	assert_not_null(counter, "main.tscn should have a ResourceCounter at UI/ResourceCounter")
