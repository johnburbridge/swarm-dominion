extends SceneTree
## Headless generator: composites a flat magenta team-color key "core" onto the
## drone placeholder frames, in place (SPI-1436). Idempotent — a frame whose
## center is already the key color is skipped, so re-runs never double-key.
##
## Run: godot --headless -s tools/generate_keyed_drone.gd

const FRAMES: Array[String] = [
	"res://assets/sprites/units/drone_idle.png",
	"res://assets/sprites/units/drone_walk_0.png",
	"res://assets/sprites/units/drone_walk_1.png",
	"res://assets/sprites/units/drone_walk_2.png",
	"res://assets/sprites/units/drone_walk_3.png",
]

## Magenta key color (matches TeamColors.KEY_HUE / the shader's key_hue default).
const KEY_COLOR: Color = Color(1, 0, 1)
## Half-size of the square key core, in pixels, centered on the sprite. Sized to
## cover most of the ~32px placeholder body so team color reads across the unit's
## silhouette at RTS zoom (the body-alpha check below keeps it off transparent
## margins). Final art will instead designate a deliberate neutral key region.
const CORE_HALF: int = 10
## Minimum alpha for a pixel to count as "body" (skip transparent pixels).
const BODY_ALPHA: float = 0.5


func _init() -> void:
	for path in FRAMES:
		_key_frame(path)
	quit()


func _key_frame(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null:
		push_error("generate_keyed_drone: could not load %s" % path)
		return
	var cx := image.get_width() / 2
	var cy := image.get_height() / 2
	if image.get_pixel(cx, cy).is_equal_approx(KEY_COLOR):
		print("skip (already keyed): %s" % path)
		return
	for y in range(cy - CORE_HALF, cy + CORE_HALF):
		for x in range(cx - CORE_HALF, cx + CORE_HALF):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if image.get_pixel(x, y).a < BODY_ALPHA:
				continue
			image.set_pixel(x, y, KEY_COLOR)
	image.save_png(path)
	print("keyed: %s" % path)
