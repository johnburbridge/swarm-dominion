extends GutTest
## Tests for right-click command dispatch on biomass nodes (SPI-1386).
##
## Targets main.gd's _dispatch_command_at(click_pos, selected) and
## _get_biomass_node_at_position(pos) directly, passing an explicit selected
## array so we don't need to drive real mouse input or SelectionManager.
##
## Decision priority under test: enemy -> engage; else biomass node -> harvest;
## else -> move.

# Positions kept far from main.tscn's own spawned units/nodes (which live in the
# 500-1400 x, 300-700 y range) so point queries never cross-hit.
const NODE_POS := Vector2(5000, 0)
const EMPTY_POS := Vector2(8000, 0)
const ENEMY_POS := Vector2(6000, 0)
const SAME_POS := Vector2(7000, 0)
const DEPLETED_POS := Vector2(9000, 0)

var _main_scene: PackedScene
var _drone_scene: PackedScene
var _node_scene: PackedScene
var _main: Node


func before_all() -> void:
	_main_scene = load("res://scenes/main/main.tscn")
	_drone_scene = load("res://scenes/units/drone.tscn")
	_node_scene = load("res://scenes/resources/biomass_node.tscn")


func before_each() -> void:
	ResourceManager.reset()
	_main = _main_scene.instantiate()
	add_child_autofree(_main)


func _settle() -> void:
	# Advance a couple of physics frames so collision shapes register in the
	# shared world_2d before we run point queries.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func _create_player_unit(pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = _main.PLAYER_TEAM_ID
	unit.position = pos
	_main.add_child(unit)
	unit.harvest_speed = 5
	return unit


func _create_enemy_unit(pos: Vector2) -> UnitBase:
	var unit := _drone_scene.instantiate() as UnitBase
	unit.team_id = _main.PLAYER_TEAM_ID + 1
	unit.position = pos
	_main.add_child(unit)
	return unit


func _create_node(pos: Vector2) -> BiomassNode:
	var node := _node_scene.instantiate() as BiomassNode
	node.position = pos
	_main.add_child(node)
	return node


# --- Scenario 1: right-click a node dispatches a harvest command ---


func test_right_click_node_dispatches_harvest() -> void:
	var node := _create_node(NODE_POS)
	var unit_a := _create_player_unit(Vector2(4900, 100))
	var unit_b := _create_player_unit(Vector2(5100, 100))
	await _settle()

	var selected: Array[UnitBase] = [unit_a, unit_b]
	_main._dispatch_command_at(node.global_position, selected)

	assert_eq(unit_a._state, UnitBase.UnitState.HARVESTING, "unit_a should be HARVESTING the node")
	assert_eq(unit_b._state, UnitBase.UnitState.HARVESTING, "unit_b should be HARVESTING the node")
	assert_eq(unit_a._harvest_target, node, "unit_a should target the clicked node")
	assert_eq(unit_b._harvest_target, node, "unit_b should target the clicked node")


# --- Scenario 2: right-click empty ground moves (existing behavior) ---


func test_right_click_empty_ground_moves() -> void:
	var unit_a := _create_player_unit(Vector2(100, 100))
	var unit_b := _create_player_unit(Vector2(200, 100))
	await _settle()

	var selected: Array[UnitBase] = [unit_a, unit_b]
	_main._dispatch_command_at(EMPTY_POS, selected)

	assert_eq(unit_a._state, UnitBase.UnitState.MOVING, "unit_a should be MOVING to empty ground")
	assert_eq(unit_b._state, UnitBase.UnitState.MOVING, "unit_b should be MOVING to empty ground")


# --- Scenario 3: right-click an enemy engages (existing behavior) ---


func test_right_click_enemy_engages() -> void:
	var enemy := _create_enemy_unit(ENEMY_POS)
	var unit_a := _create_player_unit(Vector2(5900, 100))
	var unit_b := _create_player_unit(Vector2(6100, 100))
	await _settle()

	var selected: Array[UnitBase] = [unit_a, unit_b]
	_main._dispatch_command_at(enemy.global_position, selected)

	assert_eq(unit_a._state, UnitBase.UnitState.ENGAGING, "unit_a should be ENGAGING the enemy")
	assert_eq(unit_b._state, UnitBase.UnitState.ENGAGING, "unit_b should be ENGAGING the enemy")


# --- Scenario 4: enemy takes priority over a node at the same position ---


func test_enemy_takes_priority_over_node() -> void:
	var node := _create_node(SAME_POS)
	var enemy := _create_enemy_unit(SAME_POS)
	var unit_a := _create_player_unit(Vector2(6900, 100))
	var unit_b := _create_player_unit(Vector2(7100, 100))
	await _settle()

	assert_not_null(
		_main._get_biomass_node_at_position(SAME_POS),
		"node must be detectable at the overlap position for this test to prove priority"
	)

	var selected: Array[UnitBase] = [unit_a, unit_b]
	_main._dispatch_command_at(SAME_POS, selected)

	assert_eq(
		unit_a._state,
		UnitBase.UnitState.ENGAGING,
		"enemy should win: unit_a ENGAGING not HARVESTING"
	)
	assert_eq(
		unit_b._state,
		UnitBase.UnitState.ENGAGING,
		"enemy should win: unit_b ENGAGING not HARVESTING"
	)
	assert_null(unit_a._harvest_target, "unit_a should not have a harvest target")
	assert_null(unit_b._harvest_target, "unit_b should not have a harvest target")
	# Keep the node referenced so it isn't collected before the query above.
	assert_not_null(node, "node exists at the same position")


# --- Scenario 5: right-click a depleted node falls back to move ---


func test_right_click_depleted_node_moves() -> void:
	var node := _create_node(DEPLETED_POS)
	node.harvest(node.max_biomass)
	assert_true(node.is_depleted(), "node should be depleted after harvesting max_biomass")
	var unit_a := _create_player_unit(Vector2(8900, 100))
	var unit_b := _create_player_unit(Vector2(9100, 100))
	await _settle()

	var selected: Array[UnitBase] = [unit_a, unit_b]
	_main._dispatch_command_at(node.global_position, selected)

	assert_eq(
		unit_a._state, UnitBase.UnitState.MOVING, "unit_a should MOVE, not HARVEST, a depleted node"
	)
	assert_eq(
		unit_b._state, UnitBase.UnitState.MOVING, "unit_b should MOVE, not HARVEST, a depleted node"
	)
	assert_null(unit_a._harvest_target, "unit_a should not have a harvest target")
	assert_null(unit_b._harvest_target, "unit_b should not have a harvest target")


# --- Helper: _get_biomass_node_at_position finds/returns null ---


func test_get_biomass_node_at_position_finds_node() -> void:
	var node := _create_node(NODE_POS)
	await _settle()

	assert_eq(
		_main._get_biomass_node_at_position(node.global_position),
		node,
		"should return the node at its position",
	)
	assert_null(
		_main._get_biomass_node_at_position(EMPTY_POS),
		"should return null for an empty position",
	)
