extends GutTest
## Tests that UnitBase wires the team-color shader from team_id (SPI-1436).

var _drone_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")


func _create_unit(tid: int) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = tid
	add_child_autofree(unit)
	return unit


func test_unit_sprite_uses_team_color_shader_material() -> void:
	var unit := _create_unit(1)
	var mat := unit._sprite.material as ShaderMaterial
	assert_not_null(mat, "sprite should have a ShaderMaterial")
	assert_eq(mat.shader, UnitBase.TEAM_COLOR_SHADER, "should use the team-color shader")
	assert_eq(
		mat.get_shader_parameter("team_color"),
		TeamColors.color_for(1),
		"team_color param should match team 1's color"
	)


func test_team_id_two_gets_its_color() -> void:
	var unit := _create_unit(2)
	var mat := unit._sprite.material as ShaderMaterial
	assert_eq(
		mat.get_shader_parameter("team_color"),
		TeamColors.color_for(2),
		"team_color param should match team 2's color"
	)


func test_two_units_have_independent_materials() -> void:
	var u1 := _create_unit(1)
	var u2 := _create_unit(2)
	var m1 := u1._sprite.material as ShaderMaterial
	var m2 := u2._sprite.material as ShaderMaterial
	assert_ne(m1, m2, "each unit should get its own ShaderMaterial instance")
	m1.set_shader_parameter("team_color", Color.BLACK)
	assert_eq(
		m2.get_shader_parameter("team_color"),
		TeamColors.color_for(2),
		"changing one unit's material must not change another's"
	)
