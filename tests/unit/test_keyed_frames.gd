extends GutTest
## Verifies the drone placeholder frames carry the magenta team-color key core
## the shader depends on (SPI-1436). Loads the raw PNG (bypasses import format).

const FRAMES: Array[String] = [
	"res://assets/sprites/units/drone_idle.png",
	"res://assets/sprites/units/drone_walk_0.png",
	"res://assets/sprites/units/drone_walk_1.png",
	"res://assets/sprites/units/drone_walk_2.png",
	"res://assets/sprites/units/drone_walk_3.png",
]


func test_every_frame_has_a_magenta_key_core() -> void:
	for path in FRAMES:
		var image := Image.load_from_file(path)
		assert_not_null(image, "frame should load: %s" % path)
		var center := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
		assert_almost_eq(center.r, 1.0, 0.15, "%s center should be magenta (high red)" % path)
		assert_almost_eq(center.g, 0.0, 0.15, "%s center should be magenta (no green)" % path)
		assert_almost_eq(center.b, 1.0, 0.15, "%s center should be magenta (high blue)" % path)
	assert_engine_error(
		FRAMES.size(),
		"Image.load_from_file on an imported res:// path logs an 'export' warning per frame"
	)
