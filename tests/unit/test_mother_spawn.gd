extends GutTest
## Integration test (SPI-1421): the main scene spawns exactly one player Mother,
## discoverable via the standard "units" group on the player team.

var _main_scene: PackedScene


func before_all() -> void:
	_main_scene = load("res://scenes/main/main.tscn")


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
