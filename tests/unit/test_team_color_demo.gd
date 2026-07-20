extends GutTest
## Verifies the team-color demo builds three distinct-colored swatches (SPI-1436).


func test_demo_creates_three_distinct_swatches() -> void:
	var demo := preload("res://scenes/dev/team_color_demo.tscn").instantiate()
	add_child_autofree(demo)
	await get_tree().process_frame
	var swatches := get_tree().get_nodes_in_group("demo_swatches")
	assert_eq(swatches.size(), 3, "demo should create 3 swatches")
	var colors := {}
	for s in swatches:
		var mat := (s as Sprite2D).material as ShaderMaterial
		colors[mat.get_shader_parameter("team_color")] = true
	assert_eq(colors.size(), 3, "the 3 swatches should use 3 distinct team colors")
