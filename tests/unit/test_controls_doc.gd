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
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var parts: Array = []
		if key_event.shift_pressed:
			parts.append("Shift")
		if key_event.ctrl_pressed:
			parts.append("Ctrl")
		if key_event.alt_pressed:
			parts.append("Alt")
		if key_event.meta_pressed:
			parts.append("Meta")
		parts.append(OS.get_keycode_string(key_event.keycode))
		return "+".join(parts)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "MouseLeft"
			MOUSE_BUTTON_RIGHT:
				return "MouseRight"
			MOUSE_BUTTON_MIDDLE:
				return "MouseMiddle"
	return "Unknown"


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
	var regex := RegEx.new()
	regex.compile('is_action[a-z_]*\\("(?<action>[a-z_]+)"')
	var actions: Array = []
	for path in _gd_files("res://scripts"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var source := file.get_as_text()
		file.close()
		for m in regex.search_all(source):
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
	regex.compile("KEY_(?<key>[A-Z0-9]+)")
	var keys: Array = []
	for m in regex.search_all(source):
		var key := m.get_string("key")
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	return keys


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
	var body := _doc_text()
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
