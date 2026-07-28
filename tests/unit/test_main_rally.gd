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


func _key_event(keycode: int, shift: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.shift_pressed = shift
	return ev


func test_clear_rally_action_bound_to_shift_r() -> void:
	assert_true(InputMap.has_action("clear_rally"), "project should define a clear_rally action")
	var found := false
	for ev in InputMap.action_get_events("clear_rally"):
		if ev is InputEventKey and ev.keycode == KEY_R and ev.shift_pressed:
			found = true
	assert_true(found, "clear_rally should be bound to Shift+R")


func test_shift_r_clears_the_rally() -> void:
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	mother.set_rally_point(Vector2(950, 640))
	main._unhandled_input(_key_event(KEY_R, true))
	assert_false(mother.has_rally(), "Shift+R should clear the selected Mother's rally")


func test_shift_r_does_not_also_arm_rally_placement() -> void:
	# Godot matches actions non-exactly by default, so a Shift+R event ALSO matches
	# the plain-R set_rally action. Without an exact match on set_rally, clearing
	# would immediately re-arm placement and the next left-click would set a rally.
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	mother.set_rally_point(Vector2(950, 640))
	main._unhandled_input(_key_event(KEY_R, true))
	assert_false(main._rally_set_pending, "Shift+R must clear without arming placement")


func test_plain_r_still_arms_rally_placement() -> void:
	# Regression guard on the exact-match fix above: it must not stop plain R working.
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	main._unhandled_input(_key_event(KEY_R, false))
	assert_true(main._rally_set_pending, "plain R should still arm rally placement")


func test_issue_clear_rally_clears_every_selected_player_mother() -> void:
	var main := await _make_main()
	var first := _make_mother(PLAYER_TEAM)
	var second := _make_mother(PLAYER_TEAM)
	first.set_rally_point(Vector2(950, 640))
	second.set_rally_point(Vector2(120, 80))
	SelectionManager.select_units([first, second])
	main._issue_clear_rally()
	assert_false(first.has_rally(), "the first selected Mother should be cleared")
	assert_false(second.has_rally(), "the second selected Mother should be cleared too")


func test_issue_clear_rally_leaves_enemy_mothers_alone() -> void:
	var main := await _make_main()
	var enemy := _make_mother(2)
	enemy.set_rally_point(Vector2(950, 640))
	SelectionManager.select_units([enemy])
	main._issue_clear_rally()
	assert_true(enemy.has_rally(), "an enemy Mother's rally must not be clearable")


func test_issue_clear_rally_cancels_pending_placement() -> void:
	# Armed placement then a clear: leaving it armed would make the next left-click
	# silently set a new rally, undoing the clear the player just asked for.
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	main._rally_set_pending = true
	main._issue_clear_rally()
	assert_false(main._rally_set_pending, "clearing should disarm a pending rally placement")


func test_panel_signal_clears_rally() -> void:
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	mother.set_rally_point(Vector2(950, 640))
	main._spawn_panel.rally_clear_requested.emit()
	assert_false(mother.has_rally(), "the panel's clear request should clear the rally")


func test_issue_set_rally_sets_selected_mother_rally() -> void:
	var main := await _make_main()
	var mother := _make_mother(PLAYER_TEAM)
	SelectionManager.select_unit(mother)
	main._issue_set_rally(Vector2(950, 640))
	assert_true(mother.has_rally(), "issue_set_rally should set the selected Mother's rally")
	assert_eq(
		mother.get_rally_point(), Vector2(950, 640), "rally point should match the issued position"
	)
