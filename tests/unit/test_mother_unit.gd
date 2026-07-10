extends GutTest
## Tests for the Mother unit (SPI-1421): a large, slow, high-HP command unit
## that cannot harvest, cannot auto-attack, is never auto-targeted, but is
## selectable and movable like any other unit.

var _mother_scene: PackedScene
var _drone_scene: PackedScene
var _node_scene: PackedScene


func before_all() -> void:
	_mother_scene = load("res://scenes/units/mother.tscn")
	_drone_scene = load("res://scenes/units/drone.tscn")
	_node_scene = load("res://scenes/resources/biomass_node.tscn")


func before_each() -> void:
	ResourceManager.reset()


func _create_mother(tid: int, pos: Vector2) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = pos
	add_child_autofree(mother)
	return mother


func _create_drone(tid: int, pos: Vector2) -> UnitBase:
	var drone := _drone_scene.instantiate() as UnitBase
	drone.team_id = tid
	drone.position = pos
	add_child_autofree(drone)
	return drone


func _create_node(pos: Vector2) -> BiomassNode:
	var node := _node_scene.instantiate() as BiomassNode
	node.position = pos
	add_child_autofree(node)
	return node


# --- Stats & identity ---


func test_mother_loads_high_hp_stats() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.max_health, 500, "Mother max_health should load 500 from stats")
	assert_eq(mother.current_health, 500, "Mother should start at full health")


func test_mother_loads_slow_move_speed() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.move_speed, 50.0, "Mother move_speed should load 50 from stats")


func test_mother_unit_type() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.unit_type, "mother", "Mother unit_type should be 'mother'")


func test_mother_is_not_auto_targetable() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_false(mother.is_auto_targetable(), "Mother should not be auto-targetable")


func test_drone_is_auto_targetable_by_default() -> void:
	var drone := _create_drone(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_true(drone.is_auto_targetable(), "Drone should be auto-targetable by default")


# --- Behavioral exclusions ---


func test_mother_cannot_harvest() -> void:
	var node := _create_node(Vector2.ZERO)
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	mother.harvest_at(node)
	assert_false(mother.is_harvesting(), "Mother must not enter HARVESTING")
	assert_eq(mother._state, UnitBase.UnitState.IDLE, "Mother should stay IDLE after harvest_at")


func test_mother_has_no_attack_area() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	assert_eq(mother.attack_range, 0.0, "Mother attack_range should be 0 (no attack keys in stats)")
	assert_null(mother._attack_area, "Mother should build no attack Area2D")
	assert_null(mother.get_node_or_null("AttackRange"), "Mother should have no AttackRange child")


# --- Movement & selection (inherited, verified for the Mother) ---


func test_mother_moves_when_commanded() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	mother.move_to(Vector2(500, 0))
	assert_eq(mother._state, UnitBase.UnitState.MOVING, "Mother should enter MOVING on move_to")
	for _i in range(10):
		await get_tree().physics_frame
	assert_gt(mother.position.x, 0.0, "Mother should advance toward its move target")


func test_mother_selection_toggles_circle() -> void:
	var mother := _create_mother(1, Vector2.ZERO)
	await get_tree().process_frame
	mother.set_selected(true)
	assert_true(mother._selection_circle.visible, "selection circle should show when selected")
	mother.set_selected(false)
	assert_false(mother._selection_circle.visible, "selection circle should hide when deselected")
