# HARVESTING State + Gather Behavior — Design (SPI-1385)

**Issue:** [SPI-1385](https://linear.app/spiral-house/issue/SPI-1385) · Milestone M3 (Resource Gathering) · 3 pts
**Parent epic:** SPI-1334 · **Status:** Approved 2026-07-07

## Purpose

Give units the ability to gather biomass. A unit commanded to `harvest_at(node)`
walks to the node, enters a new `HARVESTING` state, and periodically credits
biomass to its team via `ResourceManager` at its `harvest_speed` rate. This is
the core of the M3 gather loop — the counter UI (SPI-1384) and right-click
dispatch (SPI-1386) build on it.

## Scope decisions

Two design choices were confirmed with the product owner:

1. **Node depletion lands here; regeneration does not.** SPI-1385 adds an extract
   API to `BiomassNode` that decrements `current_biomass` and fires the
   depletion signals. **Regeneration remains SPI-1388's scope** — the node
   only counts down in this story.
2. **`harvest_speed` is biomass per second.** `drone=5`, `scout=8` (scout
   out-gathers, matching the PRD). Biomass accrues continuously and is credited
   in whole units.

Out of scope (owned elsewhere): input wiring / right-click → harvest (SPI-1386),
node regeneration (SPI-1388), harvest progress indicator (SPI-1387).

## Component 1 — `BiomassNode.harvest()`

SPI-1382 built `BiomassNode` as a passive data holder: it declares
`biomass_changed(current, maximum)` and `biomass_depleted` signals but never
emits them, and exposes no way to remove biomass. This story fills that gap.

```gdscript
func harvest(amount: int) -> int:
    var extracted: int = min(amount, current_biomass)
    if extracted <= 0:
        return 0
    current_biomass -= extracted
    biomass_changed.emit(current_biomass, max_biomass)
    if current_biomass <= 0:
        biomass_depleted.emit()
    return extracted
```

- Returns the amount **actually** extracted, clamped to the node's remaining
  biomass — the caller credits exactly this to `ResourceManager`, so the final
  partial tick is handled naturally.
- Emits `biomass_changed` on every successful extract and `biomass_depleted`
  when the node reaches 0.
- A `harvest(0)` / negative / already-depleted call is a no-op returning 0.

## Component 2 — `UnitBase` HARVESTING state

Mirrors the existing ENGAGING state (`_process_engaging`) for the move-then-act
pattern. State is a direct `_state` assignment (no `_set_state` helper exists);
side-effects go inline at each assignment site.

**New members**

- `HARVESTING` appended to the `UnitState` enum (append avoids renumbering).
- `var harvest_speed: float` (or int) loaded in `_load_stats` via
  `unit_stats.get("harvest_speed", 0)`. Default 0 means `mother` (no value in
  `unit_stats.json`) cannot gather.
- `var _harvest_target: BiomassNode = null`
- `var _harvest_progress: float = 0.0` — fractional-biomass accumulator.

**`harvest_at(node: BiomassNode) -> void`** — mirrors `engage_unit`:

- early-return if `_state == DEAD` or `node == null` or `node.is_depleted()`.
- clear `_attack_target`, `_engage_target`, `_engage_offset`,
  `_has_attack_move_destination`; reset `_harvest_progress = 0.0`.
- set `_harvest_target = node`; `_state = HARVESTING`; `attack_stopped.emit()`.

**`_process_harvesting(delta: float) -> void`** — new `_physics_process`
match-arm (`UnitState.HARVESTING: _process_harvesting(delta)`):

- If `_harvest_target == null` or `_harvest_target.is_depleted()` →
  clear target + `_state = IDLE`; return.
- **Approach:** if distance to `_harvest_target.global_position` >
  `_harvest_target.harvest_radius` → walk toward it (`velocity`,
  `_update_animation`, `move_and_slide`), same as ENGAGING's approach leg;
  return.
- **Gather:** `_harvest_progress += harvest_speed * delta`. Extract the whole
  part: `var whole := int(_harvest_progress)`; if `whole > 0`,
  `var got := _harvest_target.harvest(whole)`;
  `ResourceManager.add_resources(team_id, got)`;
  `_harvest_progress -= got` (subtract what was actually taken, not `whole`, so
  a clamped final tick doesn't drop fractional progress). If `got == 0` the node
  is spent → clear + IDLE next frame via the depletion check.

**Cleanup / cancellation** — add `_harvest_target = null` and
`_harvest_progress = 0.0` to: `move_to`, `attack_move_to`, `engage_unit`
(so a new command cancels harvesting) and `_die` (dead units drop the target).

**Free behaviors** (no extra code):

- `_is_moving` false while harvesting — the getter lists MOVING/ATTACK_MOVING/
  ENGAGING only; HARVESTING is deliberately omitted.
- Auto-attack suppressed — `_process_harvesting` never calls
  `_try_acquire_target` and never transitions to ATTACKING, so enemies in range
  are ignored while gathering.

## Data flow

`harvest_at(node)` → HARVESTING → approach → per-frame accrual →
`node.harvest(whole)` decrements the node + emits `biomass_changed` →
`ResourceManager.add_resources(team_id, got)` emits `resources_changed` →
(SPI-1384 counter UI will consume). Node hits 0 → `biomass_depleted` → unit
returns to IDLE.

## Testing (TDD, mirrors `tests/unit/test_engage_unit.gd`)

**`test_biomass_node.gd`** (extend existing):

1. `harvest(n)` extracts `n` and decrements `current_biomass`.
2. `harvest(n)` clamps to remaining and returns the clamped amount.
3. `harvest` emits `biomass_changed` with `(current, maximum)`.
4. `harvest` that empties the node emits `biomass_depleted`.
5. `harvest(0)` / on a depleted node → returns 0, no emit.

**`test_unit_harvest.gd`** (new) — the 6 acceptance scenarios + depletion:

1. `harvest_at` from afar → unit walks to node, becomes HARVESTING on arrival.
2. Harvesting accrues biomass to the unit's team via ResourceManager over time
   (scout out-accrues drone across the same frame count).
3. Enemy in range while HARVESTING → no auto-attack (state stays HARVESTING,
   no `_attack_target`).
4. `move_to` / `attack_move_to` / `engage_unit` each cancel HARVESTING and null
   `_harvest_target`.
5. `_is_moving` is false while HARVESTING.
6. Dead unit issued `harvest_at` stays DEAD.
7. Node depleting mid-harvest returns the unit to IDLE.

Harness: `add_child_autofree` a `drone.tscn` (`team_id`, `position`),
`add_child_autofree` a `biomass_node.tscn`, advance `await
get_tree().physics_frame` to drive `_physics_process`, assert on private
`_state` / `_harvest_target` and on `ResourceManager.get_resources(team_id)`.
`before_each` calls `ResourceManager.reset()` for isolation.
