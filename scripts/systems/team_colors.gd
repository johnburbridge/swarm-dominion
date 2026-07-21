class_name TeamColors extends RefCounted
## Single source of truth mapping team_id -> the color a unit renders in via the
## team-color palette-swap shader (SPI-1436). Pure data; no scene tree.

## Hue of the team-color key region in authored sprites (magenta). Kept in sync
## with the `key_hue` default in assets/shaders/team_color.gdshader.
const KEY_HUE: float = 0.8333

## Color used when a team_id has no assigned color (unset / neutral). White is a
## visual no-op for the shader (keyed pixels render at their own luminance).
const NEUTRAL: Color = Color.WHITE

## Absolute per-team colors. Team 1 green, team 2 red — same intent as the old
## map_loader modulate stopgap, now full colors instead of a whitewash tint.
const TEAM_COLORS: Dictionary = {
	1: Color(0.3, 0.85, 0.35),
	2: Color(0.9, 0.3, 0.3),
}


## Returns the color for team_id, or NEUTRAL if the team has no assigned color.
static func color_for(team_id: int) -> Color:
	return TEAM_COLORS.get(team_id, NEUTRAL)
