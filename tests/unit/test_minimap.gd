extends GutTest
## Tests for Minimap coordinate projection and configuration (SPI-1373).

var _minimap: Minimap


func before_each() -> void:
	_minimap = Minimap.new()
	_minimap.custom_minimum_size = Minimap.MINIMAP_SIZE
	_minimap.size = Minimap.MINIMAP_SIZE
	add_child_autofree(_minimap)
	await get_tree().process_frame


# --- Coordinate projection tests ---


func test_map_origin_maps_to_minimap_origin() -> void:
	var result := _minimap.world_to_minimap(Minimap.MAP_ORIGIN)
	assert_eq(result, Vector2.ZERO, "map origin should map to minimap origin")


func test_map_bottom_right_maps_to_minimap_bottom_right() -> void:
	var result := _minimap.world_to_minimap(Minimap.MAP_ORIGIN + Minimap.MAP_SIZE)
	assert_eq(result, Minimap.MINIMAP_SIZE, "map bottom-right should map to minimap bottom-right")


func test_map_center_maps_to_minimap_center() -> void:
	var result := _minimap.world_to_minimap(Minimap.MAP_ORIGIN + Minimap.MAP_SIZE / 2.0)
	var expected := Minimap.MINIMAP_SIZE / 2.0
	assert_almost_eq(result.x, expected.x, 0.01, "center X should map correctly")
	assert_almost_eq(result.y, expected.y, 0.01, "center Y should map correctly")


func test_minimap_origin_maps_to_map_origin() -> void:
	var result := _minimap.minimap_to_world(Vector2.ZERO)
	assert_eq(result, Minimap.MAP_ORIGIN, "minimap origin should map to map origin")


func test_minimap_bottom_right_maps_to_map_bottom_right() -> void:
	var result := _minimap.minimap_to_world(Minimap.MINIMAP_SIZE)
	var expected := Minimap.MAP_ORIGIN + Minimap.MAP_SIZE
	assert_eq(result, expected, "minimap bottom-right should map to map bottom-right")


func test_minimap_center_maps_to_map_center() -> void:
	var result := _minimap.minimap_to_world(Minimap.MINIMAP_SIZE / 2.0)
	var expected := Minimap.MAP_ORIGIN + Minimap.MAP_SIZE / 2.0
	assert_almost_eq(result.x, expected.x, 0.01, "center X should map correctly")
	assert_almost_eq(result.y, expected.y, 0.01, "center Y should map correctly")


func test_roundtrip_world_to_minimap_to_world() -> void:
	var original := Vector2(960, 540)
	var minimap_pos := _minimap.world_to_minimap(original)
	var result := _minimap.minimap_to_world(minimap_pos)
	assert_almost_eq(result.x, original.x, 0.01, "roundtrip X should preserve value")
	assert_almost_eq(result.y, original.y, 0.01, "roundtrip Y should preserve value")


func test_world_to_minimap_scales_correctly() -> void:
	var quarter := Minimap.MAP_ORIGIN + Minimap.MAP_SIZE / 4.0
	var result := _minimap.world_to_minimap(quarter)
	var expected := Minimap.MINIMAP_SIZE / 4.0
	assert_almost_eq(result.x, expected.x, 0.01, "quarter X should scale")
	assert_almost_eq(result.y, expected.y, 0.01, "quarter Y should scale")


# --- Constants sanity tests ---


func test_minimap_size_matches_map_aspect_ratio() -> void:
	var map_ratio: float = Minimap.MAP_SIZE.x / Minimap.MAP_SIZE.y
	var minimap_ratio: float = Minimap.MINIMAP_SIZE.x / Minimap.MINIMAP_SIZE.y
	assert_almost_eq(
		minimap_ratio, map_ratio, 0.02, "minimap aspect ratio should match map aspect ratio"
	)


func test_player_team_id_constant() -> void:
	assert_eq(Minimap.PLAYER_TEAM_ID, 1, "player team ID should be 1")


# --- Camera setter test ---


func test_set_camera_stores_reference() -> void:
	var camera := Camera2D.new()
	add_child_autofree(camera)
	_minimap.set_camera(camera)
	assert_eq(_minimap._camera, camera, "set_camera should store the camera reference")


func test_camera_is_null_by_default() -> void:
	assert_null(_minimap._camera, "camera should be null before set_camera is called")


# --- Mouse filter test ---


func test_mouse_filter_stops_input() -> void:
	assert_eq(
		_minimap.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"minimap should stop mouse input from passing through",
	)


# --- Clip contents test ---


func test_clip_contents_enabled() -> void:
	assert_true(_minimap.clip_contents, "minimap should clip drawing to its bounds")


# --- Viewport rect clamping tests ---


func test_viewport_rect_clamped_to_minimap_bounds() -> void:
	# Camera at map origin — half the viewport extends past the map edge
	var cam_pos := Minimap.MAP_ORIGIN
	var half_vp := Minimap.VIEWPORT_SIZE / 2.0
	var top_left := _minimap.world_to_minimap(cam_pos - half_vp)
	var bottom_right := _minimap.world_to_minimap(cam_pos + half_vp)
	var raw_rect := Rect2(top_left, bottom_right - top_left)
	var clamped := raw_rect.intersection(Rect2(Vector2.ZERO, Minimap.MINIMAP_SIZE))
	# Raw rect should extend past minimap origin (negative coords)
	assert_true(
		raw_rect.position.x < 0.0 or raw_rect.position.y < 0.0,
		"raw rect should bleed outside minimap",
	)
	# Clamped rect should stay within bounds
	assert_true(clamped.position.x >= 0.0, "clamped rect left should be >= 0")
	assert_true(clamped.position.y >= 0.0, "clamped rect top should be >= 0")
	assert_true(
		clamped.end.x <= Minimap.MINIMAP_SIZE.x,
		"clamped rect right should be <= minimap width",
	)
	assert_true(
		clamped.end.y <= Minimap.MINIMAP_SIZE.y,
		"clamped rect bottom should be <= minimap height",
	)


# --- Click-to-navigate camera tests ---


func test_click_sets_camera_position() -> void:
	var camera := Camera2D.new()
	add_child_autofree(camera)
	_minimap.set_camera(camera)
	var click_pos := Minimap.MINIMAP_SIZE / 2.0
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = click_pos
	_minimap._gui_input(event)
	var expected_world := _minimap.clamp_to_map(_minimap.minimap_to_world(click_pos))
	assert_almost_eq(
		camera.global_position.x,
		expected_world.x,
		0.01,
		"camera X should match clicked world position",
	)
	assert_almost_eq(
		camera.global_position.y,
		expected_world.y,
		0.01,
		"camera Y should match clicked world position",
	)


func test_click_at_edge_clamps_camera_to_map_bounds() -> void:
	var camera := Camera2D.new()
	add_child_autofree(camera)
	_minimap.set_camera(camera)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2.ZERO
	_minimap._gui_input(event)
	var half_vp := Minimap.VIEWPORT_SIZE / 2.0
	var min_cam := Minimap.MAP_ORIGIN + half_vp
	assert_almost_eq(camera.global_position.x, min_cam.x, 0.01, "camera X should be clamped to min")
	assert_almost_eq(camera.global_position.y, min_cam.y, 0.01, "camera Y should be clamped to min")
