# Spawn Command UI on the HUD — Design (SPI-1423)

**Issue:** [SPI-1423](https://linear.app/spiral-house/issue/SPI-1423) · Milestone M4 (Mothers & Spawning) · 3 pts · High
**Parent epic:** SPI-1335 · **Status:** Approved 2026-07-12

## Purpose

Give the player a clickable way to spawn Drones. A spawn button appears on the
HUD when a Mother is selected, shows the Drone's biomass cost, greys out when the
team can't afford one, and calls `MotherUnit.spawn_unit()` (SPI-1422) on click.
This is the third M4 story: SPI-1421 built the Mother, SPI-1422 built the
spawn factory (`spawn_unit()`), and this adds the player-facing control. Rally
points (SPI-1424) and the spawn animation (SPI-1425) come later.

## Scope

Everything this needs already exists; the work is a new HUD component plus one
tiny accessor:

- **Selection events** — `SelectionManager.selection_changed(selected_units:
  Array[UnitBase])` fires on every selection change; the panel keys on it to
  show/hide and to pick which Mother it targets.
- **Resource events / affordability** — `EventBus.resources_changed(team_id,
  amount)` drives live enable/disable; `ResourceManager.can_afford(team_id,
  amount) -> bool` answers affordability.
- **Spawn** — `MotherUnit.spawn_unit()` charges biomass and produces the Drone.
- **HUD pattern** — mirror `ResourceCounter` (`scripts/ui/resource_counter.gd` +
  `scenes/ui/resource_counter.tscn`): a `Control`-rooted scene under the `UI`
  `CanvasLayer`, connecting to autoload signals in `_ready`.

### Confirmed design decisions

1. **Target the first selected Mother.** When the selection contains one or more
   Mothers, the panel tracks the first `MotherUnit` in
   `SelectionManager.get_selected_units()`; one click spawns one Drone from it.
   Matches the AC's singular "a Drone is produced".
   (Rejected: spawn from every selected Mother — batch spawning adds partial-
   affordability and cost-label ambiguity for no benefit at match start, when
   there is a single Mother. Deferrable if ever wanted.)
2. **Cost via a `get_spawn_cost()` getter on `MotherUnit`.** Add a public
   `get_spawn_cost() -> int` that returns the already-loaded `_spawn_cost`. The
   panel reads the cost from the selected Mother — single source of truth, no
   JSON re-read, no new abstraction. This is what the SPI-1422 deferred note
   anticipated.
   (Rejected: extracting a shared `UnitCosts` loader now — heavier than needed
   when the panel already holds a Mother to ask; and the panel re-reading
   `upgrade_costs.json` itself — a third copy of the loader boilerplate.)
3. **Affordability keyed on the selected Mother's `team_id`.** The panel checks
   `ResourceManager.can_afford(_mother.team_id, cost)`, so it is correct for
   whichever team owns the Mother it is showing.
   (Rejected: hardcoding `PLAYER_TEAM_ID = 1` as `ResourceCounter` does — less
   robust when the panel already knows the Mother's team.)
4. **Keep the temporary `KEY_B` debug hook.** Per the story owner's call, the
   SPI-1422 `KEY_B` spawn shortcut in `main.gd` stays alongside the new button;
   this story does not touch `main.gd`'s input handling.
   (Rejected: removing `KEY_B` — the owner prefers keeping the dev shortcut for
   now.)

Out of scope: removing `KEY_B`; batch multi-Mother spawn; rally points
(SPI-1424); spawn animation (SPI-1425); supply-cap display (M5); spawning any
unit other than a Drone.

## Component — `MotherUnit` (extend `scripts/units/mother_unit.gd`)

Add one public accessor so the HUD can read the cost without touching data or
private state:

```gdscript
## The biomass cost to spawn one Drone from this Mother (loaded from data).
func get_spawn_cost() -> int:
	return _spawn_cost
```

No other change; `_spawn_cost` is already loaded in `_ready()` from
`data/upgrade_costs.json`.

## Component — `SpawnPanel` (new: `scripts/ui/spawn_panel.gd` + `scenes/ui/spawn_panel.tscn`)

### Scene (`spawn_panel.tscn`)

Mirror `resource_counter.tscn`'s structure:

- Root `Control` named `SpawnPanel`, `script = spawn_panel.gd`, **hidden by
  default** (`visible = false`), anchored bottom-left (clear of `ResourceCounter`
  at top-left and `Minimap` at bottom-right). `mouse_filter = 2` (IGNORE) so its
  empty area passes clicks through to the map.
- Child `Button` named `SpawnButton`, `mouse_filter = 0` (STOP) so it receives
  clicks. A sensible `custom_minimum_size` (e.g. `Vector2(180, 40)`) so the cost
  text fits. Initial `text = "Spawn Drone"` (replaced on refresh).

The mouse_filter split (panel IGNORE, button STOP) is the "don't swallow map
clicks" gotcha handled: only the button's rect intercepts input; the rest of the
panel is transparent to the mouse.

### Script (`spawn_panel.gd`)

```gdscript
class_name SpawnPanel extends Control
## HUD command panel: shows a spawn button while a Mother is selected, greys it
## out when the owning team can't afford a Drone, and spawns on click.

var _mother: MotherUnit = null

@onready var _button: Button = $SpawnButton


func _ready() -> void:
	visible = false
	_button.pressed.connect(_on_spawn_pressed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	EventBus.resources_changed.connect(_on_resources_changed)


func _on_selection_changed(selected_units: Array[UnitBase]) -> void:
	_mother = _first_mother(selected_units)
	if _mother == null:
		visible = false
		return
	visible = true
	_refresh()


func _on_resources_changed(team_id: int, _amount: int) -> void:
	if visible and _mother != null and team_id == _mother.team_id:
		_refresh()


func _on_spawn_pressed() -> void:
	if is_instance_valid(_mother):
		_mother.spawn_unit()


func _refresh() -> void:
	var cost := _mother.get_spawn_cost()
	_button.text = "Spawn Drone (%d)" % cost
	_button.disabled = not ResourceManager.can_afford(_mother.team_id, cost)


func _first_mother(units: Array[UnitBase]) -> MotherUnit:
	for unit in units:
		if unit is MotherUnit:
			return unit
	return null
```

Notes:
- A disabled Godot `Button` emits no `pressed` signal, so the "clicking a greyed
  button does nothing" AC is satisfied by the `disabled` state alone;
  `spawn_unit()` is additionally self-guarding (returns `null` without charging
  when unaffordable), so no free or double spend is possible.
- After a successful spawn, `spawn_unit()` → `ResourceManager.spend_resources`
  emits `resources_changed`, which calls `_refresh()` and re-disables the button
  if the team can no longer afford another Drone — live feedback with no extra
  wiring.
- If the tracked Mother dies while selected, `SelectionManager.remove_unit`
  emits `selection_changed`; the panel re-evaluates and hides (or retargets)
  accordingly.

## Component — `main.tscn` (modify)

Add a `SpawnPanel` instance under the existing `UI` `CanvasLayer` (alongside
`ResourceCounter`), so it renders on the HUD and connects its signals on ready.
It starts hidden.

## Data flow

Player selects a Mother → `SelectionManager.selection_changed` →
`SpawnPanel._on_selection_changed` finds the first `MotherUnit`, shows the panel,
`_refresh()` sets the cost label and the `disabled` state from
`ResourceManager.can_afford(mother.team_id, mother.get_spawn_cost())`. Player
clicks an enabled button → `_on_spawn_pressed` → `mother.spawn_unit()` → Drone
produced + biomass spent → `resources_changed` → `_refresh()` re-evaluates
affordability. Player deselects (or selects only non-Mothers) →
`selection_changed` with no Mother → panel hides.

## Testing (TDD, new `tests/unit/test_spawn_panel.gd`)

Load the scene by **string path** (`load("res://scenes/ui/spawn_panel.tscn")`)
and never reference the `SpawnPanel` class as a type in the test — the
production script/scene don't exist at RED, and referencing the type would make
the file fail to parse (GUT silently skips an unparseable file — a false green).
Reset `ResourceManager` in `before_each`. Instantiate a real `MotherUnit` from
`mother.tscn` and drive selection through `SelectionManager`.

A helper reads the expected cost from the selected Mother
(`mother.get_spawn_cost()`) so no assertion hardcodes `25`.

**Structure & visibility:**

1. Panel has a `Button` child named `SpawnButton`.
2. Fresh panel (no selection) is hidden (`visible == false`).
3. Selecting a non-Mother (a Drone) leaves the panel hidden.
4. Selecting a Mother makes the panel visible.
5. Deselecting (selection cleared) hides the panel again.

**Cost display:**

6. When visible, the button text is `"Spawn Drone (%d)" % mother.get_spawn_cost()`
   (data-driven, not hardcoded).

**Affordability & spawn:**

7. Mother selected, team funded above cost → `SpawnButton.disabled == false`;
   invoking the button's `pressed` (or `_on_spawn_pressed`) spawns a Drone
   (team-1 `unit_type == "drone"` appears / biomass drops by the cost).
8. Mother selected, team below cost → `SpawnButton.disabled == true`, and no
   Drone is produced / no biomass spent (guard holds even if `pressed` is
   emitted, since `spawn_unit()` self-guards).
9. Live update: Mother selected while unaffordable (button disabled); after
   `ResourceManager.add_resources` brings the team above cost, the button becomes
   enabled (`disabled == false`) via `resources_changed`.

**Accessor:**

10. `MotherUnit.get_spawn_cost()` returns the loaded `_spawn_cost`.

**Integration:**

11. `main.tscn` has a `SpawnPanel` at `UI/SpawnPanel`, hidden on load.

**Regression:** existing `ResourceCounter`, Mother, and spawn tests stay green;
the new getter is additive, and the panel is a new, initially-hidden node.

## Files touched

- Create: `scripts/ui/spawn_panel.gd`
- Create: `scenes/ui/spawn_panel.tscn`
- Create: `tests/unit/test_spawn_panel.gd`
- Modify: `scripts/units/mother_unit.gd` (add `get_spawn_cost()`)
- Modify: `scenes/main/main.tscn` (instance `SpawnPanel` under `UI`)
- No change: `scripts/main.gd` (KEY_B kept as-is),
  `scripts/autoload/selection_manager.gd`, `scripts/autoload/resource_manager.gd`,
  `data/upgrade_costs.json`
