extends GutTest
## Drift guard for docs/CONTROLS.md: every input action declared in project.godot must
## be documented, and the doc must not claim actions that no longer exist. Without
## this, adding a binding silently ships it undocumented — which is how R, Shift+R,
## A and Ctrl+1-5 all ended up unreachable for anyone who had not read the source.
##
## Two checks, because either alone is weak: the manifest comment gives exact two-way
## equality, and the body check stops the manifest being updated in isolation without
## the action being mentioned anywhere a reader would see it.

const DOC_PATH: String = "res://docs/CONTROLS.md"
## Godot registers its own ui_* actions (ui_accept, ui_left, ...) in every project.
## They are engine defaults, not game bindings, and are not worth documenting.
## Consequence: a game action named ui_* would be silently exempt from every check
## here, so do not prefix game actions with ui_.
const ENGINE_ACTION_PREFIX: String = "ui_"


func _doc_text() -> String:
	var file := FileAccess.open(DOC_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Action names declared by the project, engine defaults excluded.
func _declared_actions() -> Array:
	var actions: Array = []
	for action in InputMap.get_actions():
		var name := str(action)
		if not name.begins_with(ENGINE_ACTION_PREFIX):
			actions.append(name)
	actions.sort()
	return actions


## Action names listed in the doc's machine-readable manifest comment.
func _manifest_actions(text: String) -> Array:
	# Deduplicated: an action bound to two keys needs two manifest entries to satisfy
	# the key check, and without this dedup the name check would then reject the
	# duplicate — leaving no manifest that satisfies both, and no way to add a second
	# binding without deleting a guard.
	var entries: Array = []
	for pair in _manifest_bindings(text):
		var name := str(pair).split(":")[0]
		if not entries.has(name):
			entries.append(name)
	entries.sort()
	return entries


## "name:key" bindings listed in the doc's manifest comment.
func _manifest_bindings(text: String) -> Array:
	var regex := RegEx.new()
	regex.compile("<!--\\s*input-actions:\\s*(?<list>[^>]*?)\\s*-->")
	var found := regex.search(text)
	if found == null:
		return []
	var bindings: Array = []
	for entry in found.get_string("list").split(","):
		var trimmed := entry.strip_edges()
		if not trimmed.is_empty():
			bindings.append(trimmed)
	bindings.sort()
	return bindings


## Human-readable key for one bound event, matching the manifest's notation.
func _binding_label(event: InputEvent) -> String:
	var base := ""
	if event is InputEventKey:
		base = OS.get_keycode_string((event as InputEventKey).keycode)
	elif event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				base = "MouseLeft"
			MOUSE_BUTTON_RIGHT:
				base = "MouseRight"
			MOUSE_BUTTON_MIDDLE:
				base = "MouseMiddle"
	if base.is_empty():
		return "Unknown"
	# Modifiers apply to mouse bindings too. Reading them only off key events meant
	# Shift+RightClick and plain RightClick produced the same label, so the key-drift
	# check could not see a modifier being added to a mouse binding.
	var parts: Array = []
	if event.is_class("InputEventWithModifiers"):
		if event.shift_pressed:
			parts.append("Shift")
		if event.ctrl_pressed:
			parts.append("Ctrl")
		if event.alt_pressed:
			parts.append("Alt")
		if event.meta_pressed:
			parts.append("Meta")
	parts.append(base)
	return "+".join(parts)


## "name:key" for every declared action, as the manifest should spell them.
func _declared_bindings() -> Array:
	var bindings: Array = []
	for action in _declared_actions():
		for event in InputMap.action_get_events(action):
			bindings.append("%s:%s" % [action, _binding_label(event)])
	bindings.sort()
	return bindings


## Every .gd file under scripts/, recursively.
func _gd_files(dir_path: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			files.append_array(_gd_files(full))
		elif entry.ends_with(".gd"):
			files.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return files


## Actions the code actually reads, from is_action*() call sites under scripts/.
## Complements the manifest: that covers what project.godot declares, this covers what
## is wired up — including engine-default actions like ui_cancel, which drive real
## behaviour (Escape pauses the game) yet are excluded from the manifest as defaults.
## Without this check the ui_ exemption is a hole rather than a convenience.
func _actions_used_in_code() -> Array:
	var actions: Array = []
	for path in _gd_files("res://scripts"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var source := file.get_as_text()
		file.close()
		for name in _actions_in_source(source):
			if not actions.has(name):
				actions.append(name)
	actions.sort()
	return actions


## Strips line comments so a KEY_* or action name discussed in prose is not mistaken
## for a call site. Naive about "#" inside string literals; none exist in scripts/.
func _without_comments(source: String) -> String:
	var kept: Array = []
	for line in source.split("\n"):
		var hash_at := str(line).find("#")
		kept.append(line if hash_at < 0 else str(line).substr(0, hash_at))
	return "\n".join(kept)


## Action names read by `source`. Covers the whole family of action-reading APIs, not
## just is_action*: Input.get_vector() is how WASD panning gets written, and it would
## otherwise go live while the doc still said the camera actions were unimplemented.
## Tolerates newlines inside the argument list because gdformat reflows long calls,
## which would otherwise drop a call site from the scan with no semantic change at all.
## That tolerance comes from the [^)] character class, not from a (?s) flag — (?s) only
## affects ".", which this pattern never uses.
func _actions_in_source(source: String) -> Array:
	var callers := RegEx.new()
	callers.compile(
		(
			"(?:is_action[a-z_]*|get_vector|get_axis|get_action_strength"
			+ "|get_action_raw_strength|action_press|action_release)\\s*\\(([^)]*)\\)"
		)
	)
	var literals := RegEx.new()
	literals.compile('"(?<action>[a-z][a-z0-9_]*)"')
	var actions: Array = []
	for call in callers.search_all(_without_comments(source)):
		for m in literals.search_all(call.get_string(1)):
			var name := m.get_string("action")
			if not actions.has(name):
				actions.append(name)
	actions.sort()
	return actions


## Keys handled as raw KEY_* constants in main.gd, outside the input map entirely.
func _hardcoded_keys() -> Array:
	var file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	if file == null:
		return []
	var source := file.get_as_text()
	file.close()
	var regex := RegEx.new()
	regex.compile("KEY_(?<key>[A-Z0-9_]+)")
	var keys: Array = []
	for m in regex.search_all(_without_comments(source)):
		# Round-trip through the engine so this check and _binding_label share one
		# notation ("Escape", not "ESCAPE"). A constant that is not a keycode at all
		# (KEY_MASK_SHIFT, or an unrelated KEY_-prefixed name) resolves to 0 and drops.
		var keycode := OS.find_keycode_from_string(m.get_string("key").to_lower().capitalize())
		var key := OS.get_keycode_string(keycode)
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	keys.sort()
	return keys


## The doc minus its "Declared but not implemented" section. That section names keys
## precisely to say they do nothing, so a bare substring search over the whole file
## would let it satisfy a check asserting those keys ARE handled.
func _live_doc_text() -> String:
	var text := _doc_text()
	var cut := text.find("## Declared but not implemented")
	return text if cut < 0 else text.substr(0, cut)


func test_controls_doc_exists() -> void:
	assert_false(_doc_text().is_empty(), "docs/CONTROLS.md should exist and be non-empty")


func test_manifest_matches_the_declared_input_actions() -> void:
	var text := _doc_text()
	var manifest := _manifest_actions(text)
	assert_false(
		manifest.is_empty(), "docs/CONTROLS.md should carry an <!-- input-actions: ... --> manifest"
	)
	assert_eq(
		manifest,
		_declared_actions(),
		(
			"docs/CONTROLS.md's manifest must match project.godot exactly — "
			+ "document new bindings and drop removed ones"
		)
	)


func test_manifest_records_the_key_each_action_is_bound_to() -> void:
	# Names alone are not enough: rebinding set_rally from R to T changes no name, so a
	# name-only guard stays green while the doc tells players to press the wrong key.
	# That is the likeliest drift of all, and the original guard could not see it.
	var manifest := _manifest_bindings(_doc_text())
	assert_eq(
		manifest,
		_declared_bindings(),
		(
			"docs/CONTROLS.md's manifest must record each action's key as name:key — "
			+ "update it when a binding moves"
		)
	)


func test_every_action_the_code_reads_is_documented() -> void:
	# The manifest only sees actions project.godot declares, and the ui_ filter hides
	# engine-default names. An action can therefore drive real behaviour while every
	# other check here stays green — which is exactly how Escape/pause went undocumented.
	var body := _doc_text()
	var used := _actions_used_in_code()
	assert_false(used.is_empty(), "the is_action scan of scripts/ should find something to check")
	for action in used:
		assert_true(
			body.contains("`%s`" % action),
			"docs/CONTROLS.md should document the `%s` action, which scripts/ reads" % action
		)


func test_every_binding_has_a_readable_key_label() -> void:
	# _binding_label() falls back to "Unknown" for event types it does not handle, and
	# to "" for a physical-only key. Either would let a manifest entry like
	# "zoom_in:Unknown" satisfy the key check while telling a reader nothing.
	for action in _declared_actions():
		for event in InputMap.action_get_events(action):
			var label := _binding_label(event)
			assert_false(
				label.is_empty() or label == "Unknown",
				(
					"`%s` is bound to an event _binding_label() cannot name — teach it that type"
					% action
				)
			)


func test_keys_handled_outside_the_input_map_are_documented() -> void:
	# main.gd matches some keys as raw KEY_* constants, so they never appear in the
	# input map and the action checks above cannot see them at all.
	var body := _live_doc_text()
	var keys := _hardcoded_keys()
	# Without this the scan finding nothing would look like the doc being complete.
	assert_false(keys.is_empty(), "the KEY_* scan of main.gd should find something to check")
	for key in keys:
		assert_true(
			body.contains("<kbd>%s</kbd>" % key),
			(
				"docs/CONTROLS.md should document <kbd>%s</kbd>, handled as KEY_%s in main.gd"
				% [key, key]
			)
		)


func test_every_declared_action_is_mentioned_in_the_body() -> void:
	var text := _doc_text()
	# Strip the manifest so it cannot satisfy this check on its own.
	var regex := RegEx.new()
	regex.compile("<!--\\s*input-actions:[^>]*?-->")
	var body := regex.sub(text, "", true)
	for action in _declared_actions():
		assert_true(
			body.contains("`%s`" % action),
			"docs/CONTROLS.md should mention the `%s` action outside the manifest" % action
		)


# --- hardening (SPI-1459) ---


## Raw keys listed in the doc's second manifest comment.
func _manifest_raw_keys(text: String) -> Array:
	var regex := RegEx.new()
	regex.compile("<!--\\s*raw-keys:\\s*(?<list>[^>]*?)\\s*-->")
	var found := regex.search(text)
	if found == null:
		return []
	var keys: Array = []
	for entry in found.get_string("list").split(","):
		var trimmed := entry.strip_edges()
		if not trimmed.is_empty():
			keys.append(trimmed)
	keys.sort()
	return keys


func test_mouse_bindings_record_their_modifiers() -> void:
	# _binding_label built modifier prefixes only for key events, so rebinding
	# `command` from right-click to Shift+right-click produced a byte-identical
	# manifest — invisible to the very check meant to catch rebinds.
	var shift_right := InputEventMouseButton.new()
	shift_right.button_index = MOUSE_BUTTON_RIGHT
	shift_right.shift_pressed = true
	var plain_right := InputEventMouseButton.new()
	plain_right.button_index = MOUSE_BUTTON_RIGHT
	assert_ne(
		_binding_label(shift_right),
		_binding_label(plain_right),
		"a modifier on a mouse binding must change its label"
	)


func test_code_scan_sees_actions_read_without_is_action() -> void:
	# Input.get_vector() is the idiomatic way to implement WASD panning and contains
	# no "is_action", so the scan would miss the moment camera_* went live.
	var source := 'var dir := Input.get_vector("camera_left", "camera_right", "cam_up", "cam_down")'
	assert_true(
		_actions_in_source(source).has("cam_up"),
		"the scan should see actions read through Input.get_vector"
	)


func test_code_scan_survives_a_reflowed_call() -> void:
	# gdformat reflows long calls; the old regex needed (" on one line, so formatting
	# alone could drop a call site from the scan with no semantic change.
	var source := 'if event.is_action_pressed(\n\t\t"reflowed_action", false, true\n\t):'
	assert_true(
		_actions_in_source(source).has("reflowed_action"),
		"a call split across lines should still be scanned"
	)


func test_code_scan_ignores_commented_out_mentions() -> void:
	var source := '# don\'t use is_action_pressed("ghost_action") here\nvar x := 1'
	assert_false(
		_actions_in_source(source).has("ghost_action"),
		"a mention inside a comment should not be treated as a call site"
	)


func test_raw_key_manifest_matches_the_keys_main_actually_handles() -> void:
	# Two-way, so deleting the temporary KEY_B debug spawn fails the build instead of
	# leaving the doc promising a hotkey nothing handles.
	var manifest := _manifest_raw_keys(_doc_text())
	assert_false(manifest.is_empty(), "docs/CONTROLS.md should carry a <!-- raw-keys: ... --> list")
	assert_eq(
		manifest,
		_hardcoded_keys(),
		"the raw-keys manifest must match the KEY_* constants main.gd handles, both ways"
	)


func test_declared_but_unimplemented_section_cannot_satisfy_the_key_check() -> void:
	# <kbd>W</kbd>, <kbd>S</kbd> and <kbd>D</kbd> already appear there saying they do
	# nothing. Without scoping, adding raw KEY_W handling would be "documented" by the
	# sentence stating W is unimplemented.
	var live := _live_doc_text()
	assert_false(
		live.contains("Declared but not implemented"),
		"the key checks should read only the part of the doc describing live controls"
	)
	assert_true(live.contains("<kbd>B</kbd>"), "…while still covering the real control tables")
