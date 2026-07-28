extends GutTest
## Tests for unit facing (SPI-1455): a unit's sprite rotates to point along its
## heading instead of only mirroring horizontally, retains the facing it stopped
## with, and leaves the body and its upright UI siblings untouched.

var _drone_scene: PackedScene
var _mother_scene: PackedScene


func before_all() -> void:
	_drone_scene = load("res://scenes/units/drone.tscn")
	_mother_scene = load("res://scenes/units/mother.tscn")


func _create_drone(pos: Vector2) -> UnitBase:
	var drone := _drone_scene.instantiate() as UnitBase
	drone.team_id = 1
	drone.position = pos
	add_child_autofree(drone)
	return drone


func _create_mother(pos: Vector2) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = 1
	mother.position = pos
	add_child_autofree(mother)
	return mother


## The world-space direction the sprite's art points. The art's forward axis is up
## (-Y) — the Drone's head sits at the top of the frame — so the sprite points
## Vector2.UP turned by its own rotation. Asserting on this rather than on
## `rotation` directly states the tests as "which way is the creature pointing",
## so an offset with the wrong sign fails instead of matching the formula twice.
func _facing(unit: UnitBase) -> Vector2:
	return Vector2.UP.rotated(unit._sprite.rotation)


## Sends `unit` a long way along `heading` and lets the movement state run, then
## returns the normalized heading for comparison.
func _send(unit: UnitBase, heading: Vector2) -> Vector2:
	unit.move_to(unit.position + heading * 10.0)
	await wait_physics_frames(2)
	return heading.normalized()


func test_moving_east_points_the_sprite_east() -> void:
	var drone := _create_drone(Vector2(400, 300))
	var heading: Vector2 = await _send(drone, Vector2(200, 0))
	assert_almost_eq(_facing(drone).dot(heading), 1.0, 0.001, "sprite should point east")


func test_moving_south_points_the_sprite_south() -> void:
	# The case horizontal mirroring could never express: before SPI-1455 a
	# southbound unit produced no visual change at all and still read as north.
	var drone := _create_drone(Vector2(400, 300))
	var heading: Vector2 = await _send(drone, Vector2(0, 200))
	assert_almost_eq(_facing(drone).dot(heading), 1.0, 0.001, "sprite should point south")


func test_moving_diagonally_points_the_sprite_along_the_diagonal() -> void:
	var drone := _create_drone(Vector2(400, 300))
	var heading: Vector2 = await _send(drone, Vector2(-150, -150))
	assert_almost_eq(
		_facing(drone).dot(heading), 1.0, 0.001, "sprite should point up-left, not merely mirror"
	)


func test_sprite_is_rotated_not_mirrored() -> void:
	# Rotation replaces the old flip_h mirror rather than supplementing it; leaving
	# both in place would mirror an already-turned sprite.
	var drone := _create_drone(Vector2(400, 300))
	var heading: Vector2 = await _send(drone, Vector2(-200, 0))
	assert_false(drone._sprite.flip_h, "a westbound unit should turn, not flip")
	assert_almost_eq(_facing(drone).dot(heading), 1.0, 0.001, "and it should point west")


func test_facing_turns_back_when_the_heading_reverses() -> void:
	# North is the one direction a turned-away unit must be able to return to, and
	# the one the other tests avoid asserting because it is the art's rest pose.
	var drone := _create_drone(Vector2(400, 300))
	await _send(drone, Vector2(0, 200))
	assert_almost_eq(_facing(drone).dot(Vector2.DOWN), 1.0, 0.001, "precondition: turned south")
	var heading: Vector2 = await _send(drone, Vector2(0, -200))
	assert_almost_eq(_facing(drone).dot(heading), 1.0, 0.001, "reversing should turn it back north")


func test_facing_is_retained_when_the_unit_goes_idle() -> void:
	var drone := _create_drone(Vector2(400, 300))
	drone.move_to(Vector2(420, 300))  # a short hop east, reached in a few frames
	await wait_physics_frames(30)
	assert_eq(drone._state, UnitBase.UnitState.IDLE, "the drone should have arrived")
	assert_almost_eq(
		_facing(drone).dot(Vector2.RIGHT),
		1.0,
		0.001,
		"an idle unit keeps the facing it stopped with"
	)


func test_body_and_ui_siblings_stay_upright() -> void:
	var drone := _create_drone(Vector2(400, 300))
	drone.set_selected(true)
	await _send(drone, Vector2(0, 200))
	assert_ne(drone._sprite.rotation, 0.0, "precondition: the sprite has actually turned")
	assert_eq(drone.rotation, 0.0, "the body must not rotate — collision is unaffected")
	var health_bar: Control = drone.get_node("HealthBar")
	var harvest_indicator: Control = drone.get_node("HarvestIndicator")
	assert_eq(health_bar.rotation, 0.0, "the health bar should stay upright")
	assert_eq(harvest_indicator.rotation, 0.0, "the harvest indicator should stay upright")
	assert_eq(drone._selection_circle.rotation, 0.0, "the selection highlight should stay upright")


func test_attacker_faces_an_enemy_directly_below() -> void:
	# A purely vertical target: the case the old flip_h-only facing could not show.
	# Below, not above — the art already points north at rotation 0, so an enemy to
	# the north would be satisfied by doing nothing at all. The horizontal cases
	# stay with the rest of auto-attack's AC4 in test_unit_auto_attack.gd.
	var attacker := _create_drone(Vector2(400, 300))
	var enemy := _drone_scene.instantiate() as UnitBase
	enemy.team_id = 2
	enemy.position = attacker.position + Vector2(0, 50)  # inside the 80px attack range
	add_child_autofree(enemy)
	await get_tree().process_frame
	await wait_physics_frames(4)
	assert_eq(attacker._state, UnitBase.UnitState.ATTACKING, "precondition: attacking the enemy")
	assert_almost_eq(_facing(attacker).dot(Vector2.DOWN), 1.0, 0.001, "attacker should point south")


func test_mother_rotates_to_face_her_heading() -> void:
	# Her heading is load-bearing for spawn placement (SPI-1429), so she reads wrong
	# if the Drones trail a direction her sprite does not show.
	var mother := _create_mother(Vector2(400, 300))
	var heading: Vector2 = await _send(mother, Vector2(200, 0))
	assert_almost_eq(_facing(mother).dot(heading), 1.0, 0.001, "the Mother should point east too")
