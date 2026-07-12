# Mother Spawns a Drone (paid in biomass) — Design (SPI-1422)

**Issue:** [SPI-1422](https://linear.app/spiral-house/issue/SPI-1422) · Milestone M4 (Mothers & Spawning) · 3 pts · High
**Parent epic:** SPI-1335 · **Status:** Approved 2026-07-11

## Purpose

Give the Mother its defining ability: convert stored biomass into a new Level 1
Drone. This is the second M4 story, building on the Mother unit itself
(SPI-1421). It delivers **logic and signals only** — `MotherUnit.spawn_unit()`
that charges the team's biomass, instantiates a Drone clear of the Mother's
body, and announces the spawn. No spawn button / HUD (that is SPI-1423) and no
rally point (SPI-1424) — the spawned Drone simply joins the game immediately
controllable through the existing selection path.

## Scope

Everything this story needs already exists except the spawn method itself:

- **Per-team biomass** — `ResourceManager.spend_resources(team_id, amount)`
  (SPI-1383) already deducts *atomically*: it returns `false` and leaves the
  ledger untouched when the team cannot afford `amount`, and returns `true`
  after deducting when it can. One call satisfies both the "biomass reduced by
  cost" and "no biomass deducted on failure" acceptance criteria.
- **Spawn cost data** — `data/upgrade_costs.json` already carries
  `spawn_costs.drone.biomass = 25`. The data-driven-cost AC is met by *reading*
  this path; no data change is required.
- **Spawn announcement** — `EventBus.unit_spawned(unit: Node)` already exists
  and is currently emitted nowhere. This story is its first emitter (no existing
  listeners to disturb).
- **Immediately controllable** — a spawned Drone runs `UnitBase._ready()`, which
  joins the `"units"` group. Placed on the Mother's team, it is picked up by the
  existing `SelectionManager` / command path with no extra wiring.

The real work is one method on `MotherUnit`, a small cost loader beside it, and a
temporary debug key in the harness so spawning can be watched by hand.

### Confirmed design decisions

1. **Result API: return the Drone, or `null`.** `spawn_unit() -> UnitBase`
   returns the new Drone on success and `null` on insufficient biomass. On
   success it emits `EventBus.unit_spawned(drone)`. The `null` return **is** the
   failure report the AC asks for — no new `spawn_failed` signal (YAGNI; the UI
   story checks `ResourceManager.can_afford` for button state and the return
   value for the click result).
   (Rejected: adding `EventBus.spawn_failed(team_id)` now — nothing consumes it
   this story.)
2. **Placement: deterministic ring.** An internal `_spawn_count` fans successive
   Drones around the Mother — `position + Vector2.from_angle(count * ANGLE_STEP)
   * SPAWN_RADIUS`. `SPAWN_RADIUS = 60.0` clears the Mother's body
   (mother collision radius 32 + drone radius 16 = 48, leaving a 12 px gap) and
   `ANGLE_STEP = TAU / 8` keeps repeated spawns from stacking on each other.
   Uses only integer counter arithmetic — no `randf` — so it stays lockstep-safe.
   (Rejected: a single fixed offset — clears the Mother but repeated spawns pile
   onto one another until rally in SPI-1424.)
3. **Cost read: inline JSON load in `MotherUnit`.** A private
   `_load_spawn_cost()` opens `upgrade_costs.json` and reads
   `spawn_costs.drone.biomass`, mirroring the existing inline pattern in
   `UnitBase._load_stats()`. Minimal, consistent with the codebase, no refactor.
   (Rejected: extracting a shared cost/stats loader now — real DRY value arrives
   with SPI-1423 and the upgrade stories; premature here.)
4. **Harness: temporary debug key.** `main.gd` stores the player Mother and binds
   `KEY_B` to call `spawn_unit()` on it, so spawning is watchable by hand during
   playtest. Not HUD — a dev shortcut, clearly commented as temporary, to be
   superseded by the SPI-1423 spawn button.
   (Rejected: tests-only — the PRD's M4 testable outcome is "spawn units from
   Mother"; a manual hook is worth the few lines.)

Out of scope: spawn button / HUD (SPI-1423), rally points (SPI-1424), spawn
animation (SPI-1425), supply cap enforcement (M5 — `base_supply` stays unused),
and manual targeting of the Mother.

## Component — `MotherUnit` (extend `scripts/units/mother_unit.gd`)

Add the Drone scene, spawn constants, cost/counter state, a cost loader, and the
spawn method.

```gdscript
const DroneScene := preload("res://scenes/units/drone.tscn")

## Distance from the Mother's center at which Drones appear. 60 > mother body
## radius (32) + drone radius (16), so a spawned Drone never overlaps the Mother.
const SPAWN_RADIUS: float = 60.0
## Angular step between successive spawns, so repeated Drones fan out around the
## Mother rather than stacking (deterministic — no randf — for lockstep safety).
const SPAWN_ANGLE_STEP: float = TAU / 8.0

## Biomass charged per Drone, loaded from data/upgrade_costs.json in _ready.
var _spawn_cost: int = 25
## Count of Drones spawned so far; drives the placement ring angle.
var _spawn_count: int = 0
```

`_ready()` chains the base and then loads the cost:

```gdscript
func _ready() -> void:
	super._ready()
	_load_spawn_cost()
```

`_load_spawn_cost()` mirrors `UnitBase._load_stats()`:

```gdscript
func _load_spawn_cost() -> void:
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	if not file:
		push_warning("MotherUnit: Could not open upgrade_costs.json")
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_warning("MotherUnit: Failed to parse upgrade_costs.json: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data
	var spawn_costs: Dictionary = data.get("spawn_costs", {})
	var drone_cost: Dictionary = spawn_costs.get("drone", {})
	_spawn_cost = int(drone_cost.get("biomass", _spawn_cost))
```

`spawn_unit()` — charge first (atomic), then build and announce:

```gdscript
## Convert _spawn_cost biomass into a new Level 1 Drone on this Mother's team,
## placed clear of the Mother's body. Returns the new Drone, or null if the team
## cannot afford it (in which case no biomass is spent and nothing is created).
func spawn_unit() -> UnitBase:
	if not ResourceManager.spend_resources(team_id, _spawn_cost):
		return null
	var drone := DroneScene.instantiate() as UnitBase
	drone.team_id = team_id
	var angle := _spawn_count * SPAWN_ANGLE_STEP
	drone.position = position + Vector2.from_angle(angle) * SPAWN_RADIUS
	_spawn_count += 1
	get_parent().add_child(drone)
	EventBus.unit_spawned.emit(drone)
	return drone
```

Notes:
- The Drone is added to **the Mother's parent** (`get_parent()`), so it is a
  sibling in the same coordinate space — using `position` (parent-local) for
  placement is correct — and it neither moves with the Mother nor is freed when
  the Mother is freed.
- `spend_resources` returns `false` for a non-positive amount, so a mis-configured
  cost of `0` fails safe (no free Drones) rather than spawning for nothing.

## Component — `main.gd` (modify: store player Mother + debug spawn key)

Store the player Mother when the harness creates it, and add a temporary
`KEY_B` handler that spawns from it.

```gdscript
var _player_mother: MotherUnit = null
```

In `_spawn_test_units()`, capture the created Mother:

```gdscript
	var mother := MotherScene.instantiate()
	mother.team_id = 1
	mother.position = Vector2(760, 400)
	mother.modulate = Color(0.6, 1.0, 0.6)
	add_child(mother)
	_player_mother = mother
	print("Spawned player Mother")
```

In `_unhandled_input`, extend the existing key branch (which already reads
`event.keycode` for the 1–5 control-group keys) with a debug spawn key:

```gdscript
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_5:
			var group_index: int = key - KEY_1
			if event.ctrl_pressed:
				SelectionManager.assign_group(group_index)
			else:
				_recall_group(group_index)
		elif key == KEY_B:
			# TEMP (SPI-1422): debug spawn from the player Mother; replaced by
			# the spawn button in SPI-1423.
			if is_instance_valid(_player_mother):
				_player_mother.spawn_unit()
```

## Data flow

`KEY_B` (or the SPI-1423 UI later, or a test) → `player_mother.spawn_unit()` →
`ResourceManager.spend_resources(team_id, _spawn_cost)`:
- **affordable** → biomass deducted (emits `resources_changed`), Drone
  instantiated on the Mother's team at the next ring position, added as a sibling,
  `EventBus.unit_spawned(drone)` emitted; the Drone joins `"units"` in its
  `_ready` and is selectable/commandable at once. Returns the Drone.
- **not affordable** → `spend_resources` returns `false`, ledger untouched,
  nothing created. Returns `null`.

## Testing (TDD)

Use the existing GUT harness patterns (`add_child_autofree`, `watch_signals`,
`await get_tree().physics_frame`). `ResourceManager` is an autoload — reset it in
`before_each` (as the existing Mother tests already do) so per-test biomass is
clean.

### Unit tests — new `tests/unit/test_mother_spawn_drone.gd`

Reuse a Mother factory like the existing `test_mother_unit.gd` `_create_mother`.
Spawned Drones are added to the Mother's parent (the test node) but are **not**
tracked by `add_child_autofree`; each test frees the returned Drone with
`autofree(drone)` to keep the tree clean.

To keep the cost AC data-driven (not a hardcoded `25`), a helper reads the
expected value straight from the data file:

```gdscript
func _expected_spawn_cost() -> int:
	var file := FileAccess.open("res://data/upgrade_costs.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return int(json.data["spawn_costs"]["drone"]["biomass"])
```

1. **Loads cost from data:** a fresh Mother's `_spawn_cost == _expected_spawn_cost()`
   (proves decision 3 / the data-driven AC without hardcoding the number).
2. **Successful spawn deducts exactly the cost:** fund the team well above cost
   (`ResourceManager.add_resources(team, 100)`), record balance, `spawn_unit()`,
   assert balance dropped by `_expected_spawn_cost()`.
3. **Successful spawn returns a Level 1 Drone on the Mother's team:** the return
   is a `UnitBase` with `unit_type == "drone"` and `team_id == mother.team_id`.
4. **Spawn emits `unit_spawned` with the Drone:** `watch_signals(EventBus)`,
   spawn, `assert_signal_emitted(EventBus, "unit_spawned")`, and the emitted
   parameter is the returned Drone.
5. **Spawned Drone is clear of the Mother and controllable:**
   `drone.position.distance_to(mother.position)` ≥ 48 (mother 32 + drone 16), the
   Drone is `is_in_group("units")`, and `drone.get_parent() == mother.get_parent()`
   (a sibling, not a child of the Mother).
6. **Insufficient biomass → null, no deduction, no Drone:** team funded below
   cost (e.g. 0), `watch_signals(EventBus)`, record the `"units"` group size,
   `spawn_unit()`; assert the return is `null`, `get_resources(team)` unchanged,
   the group size unchanged, and `unit_spawned` **not** emitted
   (`assert_signal_not_emitted`).
7. **Repeated spawns fan out (ring):** fund generously, spawn twice; assert the
   two Drones are at different positions (distinct ring angles), confirming the
   `_spawn_count` placement.

### Integration test — extend `tests/unit/test_mother_spawn.gd`

The file already instantiates `main.tscn` and finds the player Mother via the
`"units"` group. Add one test that exercises the real scene wiring:

8. **Real-scene spawn:** instantiate `main.tscn`, advance a frame, find the
   team-1 `MotherUnit`, fund team 1 above cost, call `spawn_unit()`; assert a new
   team-1 Drone (`unit_type == "drone"`) exists as a sibling of the Mother and the
   returned value is non-null. (The `KEY_B` binding is a thin dev shortcut over
   this same call and is verified by manual playtest, not input simulation.)

**Regression:** existing `test_mother_unit.gd` and the SPI-1421
`test_mother_spawn.gd` test stay green — `MotherUnit._ready()` now calls
`super._ready()` first (unchanged base behavior) then loads the cost; the Mother
still cannot harvest or auto-attack and is still never auto-targeted.

## Files touched

- Modify: `scripts/units/mother_unit.gd` (spawn constants/state, `_ready`
  override, `_load_spawn_cost()`, `spawn_unit()`)
- Modify: `scripts/main.gd` (`_player_mother` member, capture it in
  `_spawn_test_units()`, `KEY_B` debug spawn in `_unhandled_input`)
- Create: `tests/unit/test_mother_spawn_drone.gd`
- Modify: `tests/unit/test_mother_spawn.gd` (add real-scene spawn integration test)
- No change: `data/upgrade_costs.json` (`spawn_costs.drone.biomass = 25` already
  present), `scripts/autoload/event_bus.gd` (`unit_spawned` already declared),
  `scripts/autoload/resource_manager.gd`
