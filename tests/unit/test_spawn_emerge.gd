extends GutTest
## Tests for the spawn emerge effect (SPI-1425): a purely cosmetic scale-in +
## fade-in on a spawned unit's sprite. It must NOT alter the unit's position or
## state (lockstep determinism), and only Mother-spawned units emerge — a directly
## instantiated unit (as MapLoader/tests create) stays at full scale.

var _drone_scene: PackedScene
var _mother_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")
	_mother_scene = load("res://scenes/units/mother.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _make_drone(tid: int) -> UnitBase:
	var drone := _drone_scene.instantiate() as UnitBase
	drone.team_id = tid
	drone.position = Vector2(500, 500)
	add_child_autofree(drone)
	return drone


func _make_mother(tid: int, pos: Vector2) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = pos
	add_child_autofree(mother)
	return mother


func _sprite_of(unit: UnitBase) -> Node2D:
	return unit.get_node("AnimatedSprite2D") as Node2D


func test_emerge_shrinks_and_fades_sprite() -> void:
	var drone := _make_drone(1)
	drone.play_spawn_emerge()
	var sprite := _sprite_of(drone)
	assert_lt(sprite.scale.x, 1.0, "sprite should start shrunk during emerge")
	assert_lt(sprite.modulate.a, 1.0, "sprite should start faded during emerge")


func test_emerge_does_not_move_or_change_state() -> void:
	var drone := _make_drone(1)
	var pos_before := drone.position
	var state_before := drone._state
	drone.play_spawn_emerge()
	assert_eq(
		drone.position, pos_before, "emerge must not change the unit's position (determinism)"
	)
	assert_eq(drone._state, state_before, "emerge must not change the unit's state (determinism)")


func test_emerge_settles_to_full_scale_and_opacity() -> void:
	var drone := _make_drone(1)
	drone.play_spawn_emerge()
	await get_tree().create_timer(UnitBase.EMERGE_DURATION + 0.15).timeout
	var sprite := _sprite_of(drone)
	assert_almost_eq(sprite.scale.x, 1.0, 0.01, "sprite should settle back to full scale")
	assert_almost_eq(sprite.modulate.a, 1.0, 0.01, "sprite should settle back to full opacity")


func test_spawn_unit_triggers_emerge() -> void:
	var mother := _make_mother(1, Vector2(400, 300))
	ResourceManager.add_resources(1, 100)
	var drone := mother.spawn_unit()
	autofree(drone)
	assert_not_null(drone, "spawn should succeed")
	var sprite := _sprite_of(drone)
	assert_lt(sprite.scale.x, 1.0, "a Mother-spawned Drone should start its emerge (shrunk)")


func test_map_loaded_unit_does_not_auto_emerge() -> void:
	# A directly instantiated unit (how MapLoader and tests create units) must not
	# emerge on _ready — only Mother.spawn_unit() triggers the effect.
	var drone := _make_drone(1)
	var sprite := _sprite_of(drone)
	assert_almost_eq(sprite.scale.x, 1.0, 0.01, "a non-spawned unit should be at full scale")
	assert_almost_eq(sprite.modulate.a, 1.0, 0.01, "a non-spawned unit should be at full opacity")
