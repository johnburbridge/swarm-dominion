extends Node2D
## Dev-only visual proof for the team-color shader (SPI-1436). Renders the keyed
## drone sprite in team 1, team 2, and neutral colors side by side. Not wired into
## the game; run this scene directly and screenshot for issue verification.

const TEAM_COLOR_SHADER := preload("res://assets/shaders/team_color.gdshader")
const DRONE_TEXTURE := preload("res://assets/sprites/units/drone_idle.png")
const SPACING: float = 120.0
## Teams to display, left to right. 0 = neutral.
const SWATCH_TEAMS: Array[int] = [1, 2, 0]


func _ready() -> void:
	for i in range(SWATCH_TEAMS.size()):
		var team_id: int = SWATCH_TEAMS[i]
		var sprite := Sprite2D.new()
		sprite.texture = DRONE_TEXTURE
		sprite.scale = Vector2(3, 3)
		sprite.position = Vector2((i - 1) * SPACING, 0)
		var material := ShaderMaterial.new()
		material.shader = TEAM_COLOR_SHADER
		material.set_shader_parameter("team_color", TeamColors.color_for(team_id))
		sprite.material = material
		sprite.add_to_group("demo_swatches")
		add_child(sprite)
