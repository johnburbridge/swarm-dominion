extends GutTest
## Tests for main.gd rally wiring (SPI-1424): the set_rally input action exists and
## is bound to R; the SpawnPanel's rally_set_requested arms placement; arming via the
## hotkey requires a selected player Mother; and _issue_set_rally sets the rally on
## every selected player Mother at the given position.

const PLAYER_TEAM: int = 1

var _main_scene: PackedScene
var _mother_scene: PackedScene


func before_all() -> void:
	_main_scene = load("res://scenes/main/main.tscn")
	_mother_scene = load("res://scenes/units/mother.tscn")


func before_each() -> void:
	ResourceManager.reset()
	SelectionManager.deselect_all()


func after_each() -> void:
	SelectionManager.deselect_all()


func _make_main() -> Node2D:
	var main := _main_scene.instantiate() as Node2D
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _make_mother(tid: int) -> MotherUnit:
	var mother := _mother_scene.instantiate() as MotherUnit
	mother.team_id = tid
	mother.position = Vector2(400, 300)
	add_child_autofree(mother)
	return mother


func test_set_rally_action_bound_to_r() -> void:
	assert_true(InputMap.has_action("set_rally"), "project should define a set_rally action")
	var found := false
	for ev in InputMap.action_get_events("set_rally"):
		if ev is InputEventKey and ev.keycode == KEY_R:
			found = true
	assert_true(found, "set_rally should be bound to the R key")


func test_panel_signal_arms_rally() -> void:
	var main := await _make_main()
	assert_false(main._rally_set_pending, "rally should not be armed initially")
	main._spawn_panel.rally_set_requested.emit()
	assert_true(main._rally_set_pending, "the panel request should arm rally placement")


func test_hotkey_arm_requires_player_mother_selected() -> void:
	var main := await _make_main()
	main._arm_rally_from_hotkey()
	assert_false(main._rally_set_pending, "R with no Mother selected should not arm")
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	main._arm_rally_from_hotkey()
	assert_true(main._rally_set_pending, "R with a player Mother selected should arm")


func test_issue_set_rally_sets_selected_mother_rally() -> void:
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	main._issue_set_rally(Vector2(950, 640))
	assert_true(mother.has_rally(), "issue_set_rally should set the selected Mother's rally")
	assert_eq(
		mother.get_rally_point(), Vector2(950, 640), "rally point should match the issued position"
	)
