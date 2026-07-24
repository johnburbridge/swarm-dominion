class_name RallyMarker extends Node2D
## Purely visual rally-point marker (SPI-1424): a small ring + crosshair drawn in
## a team's color via _draw(). A MotherUnit instantiates one as a world-space
## (top_level) child to show where its spawned units will rally. No game logic.

## Radius of the drawn ring, in pixels.
const RING_RADIUS: float = 10.0
## Half-length of each crosshair arm, in pixels.
const CROSSHAIR_ARM: float = 6.0
## Stroke width for the ring and crosshair.
const LINE_WIDTH: float = 2.0
## Segment count approximating the ring in draw_arc.
const RING_SEGMENTS: int = 24

var _color: Color = Color.WHITE


## Sets the marker's tint (the owning team's color) and requests a redraw.
func set_team_color(color: Color) -> void:
	_color = color
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, RING_SEGMENTS, _color, LINE_WIDTH)
	draw_line(Vector2(-CROSSHAIR_ARM, 0), Vector2(CROSSHAIR_ARM, 0), _color, LINE_WIDTH)
	draw_line(Vector2(0, -CROSSHAIR_ARM), Vector2(0, CROSSHAIR_ARM), _color, LINE_WIDTH)
