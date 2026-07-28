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
	var regex := RegEx.new()
	regex.compile("<!--\\s*input-actions:\\s*(?<list>[^>]*?)\\s*-->")
	var found := regex.search(text)
	if found == null:
		return []
	var actions: Array = []
	for entry in found.get_string("list").split(","):
		var trimmed := entry.strip_edges()
		if not trimmed.is_empty():
			actions.append(trimmed)
	actions.sort()
	return actions


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
