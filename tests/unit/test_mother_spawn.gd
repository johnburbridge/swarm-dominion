extends GutTest
## Integration test (SPI-1421): the main scene spawns exactly one player Mother,
## discoverable via the standard "units" group on the player team.

var _main_scene: PackedScene


func before_all() -> void:
	_main_scene = load("res://scenes/main/main.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _count_player_mothers() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("units"):
		if node is MotherUnit and node.team_id == 1:
			count += 1
	return count


func test_main_scene_spawns_one_player_mother() -> void:
	var main := _main_scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_eq(_count_player_mothers(), 1, "main scene should spawn exactly one player Mother")


func test_mother_spawns_drone_in_scene() -> void:
	var main := _main_scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var mother: MotherUnit = null
	for node in get_tree().get_nodes_in_group("units"):
		if node is MotherUnit and node.team_id == 1:
			mother = node
			break
	assert_not_null(mother, "player Mother should exist")
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	assert_not_null(drone, "spawn_unit should return a Drone in the real scene")
	assert_eq(drone.team_id, 1, "spawned Drone should be on the player team")
	assert_eq(
		drone.get_parent(),
		mother.get_parent(),
		"Drone should be a sibling of the Mother in the scene"
	)
