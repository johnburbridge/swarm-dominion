extends GutTest
## Tests for RallyMarker (SPI-1424): a purely visual Node2D that stores a team
## color and draws a ring + crosshair. The script is loaded by STRING PATH (never
## the `RallyMarker` class name) so this file still parses before the script exists.

const RALLY_MARKER_PATH := "res://scripts/ui/rally_marker.gd"


func _make_marker() -> Node2D:
	var script: GDScript = load(RALLY_MARKER_PATH)
	return script.new() as Node2D


func test_is_node2d() -> void:
	var marker := _make_marker()
	autofree(marker)
	assert_true(marker is Node2D, "RallyMarker should extend Node2D")


func test_default_color_is_white() -> void:
	var marker := _make_marker()
	autofree(marker)
	assert_eq(marker._color, Color.WHITE, "color should default to white before it is set")


func test_set_team_color_stores_color() -> void:
	var marker := _make_marker()
	autofree(marker)
	marker.set_team_color(Color(0.3, 0.85, 0.35))
	assert_eq(marker._color, Color(0.3, 0.85, 0.35), "set_team_color should store the color")


func test_draws_without_error_in_tree() -> void:
	var marker := _make_marker()
	marker.set_team_color(Color(0.9, 0.3, 0.3))
	add_child_autofree(marker)
	await get_tree().process_frame
	assert_true(is_instance_valid(marker), "marker should draw in-tree without error")
