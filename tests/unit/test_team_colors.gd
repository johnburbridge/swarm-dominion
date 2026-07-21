extends GutTest
## Tests for TeamColors team_id -> Color mapping (SPI-1436).


func test_color_for_returns_distinct_team_colors() -> void:
	var c1 := TeamColors.color_for(1)
	var c2 := TeamColors.color_for(2)
	assert_ne(c1, c2, "team 1 and team 2 should map to different colors")
	assert_ne(c1, TeamColors.NEUTRAL, "team 1 color should not be the neutral fallback")
	assert_ne(c2, TeamColors.NEUTRAL, "team 2 color should not be the neutral fallback")


func test_color_for_unknown_team_returns_neutral() -> void:
	assert_eq(TeamColors.color_for(0), TeamColors.NEUTRAL, "team 0 should be neutral")
	assert_eq(TeamColors.color_for(99), TeamColors.NEUTRAL, "unknown team should be neutral")


func test_key_hue_is_magenta() -> void:
	assert_almost_eq(TeamColors.KEY_HUE, 0.8333, 0.001, "key hue should be magenta (~0.8333)")
