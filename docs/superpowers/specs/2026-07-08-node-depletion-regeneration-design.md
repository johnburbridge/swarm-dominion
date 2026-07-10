# Biomass Node Depletion + Regeneration — Design (SPI-1388)

**Issue:** [SPI-1388](https://linear.app/spiral-house/issue/SPI-1388) · Milestone M3 (Resource Gathering) · 3 pts · High
**Parent epic:** SPI-1334 · **Status:** Approved 2026-07-08

## Purpose

Make biomass nodes a renewable, contested resource: they deplete as units
harvest and regrow after being left alone, so players must decide where and how
hard to harvest. This is the last M3 deliverable — it closes the gather loop
built by the node (SPI-1382), the extract API + HARVESTING state (SPI-1385), the
right-click dispatch (SPI-1386), and the counter/indicator UI (SPI-1384/1387).

## Scope

**Depletion (AC Scenarios 1–2) already shipped in SPI-1385.** `BiomassNode.harvest()`
decrements `current_biomass`, emits `biomass_changed` / `biomass_depleted`, and a
unit harvesting an emptied node returns to IDLE. This story adds what is missing:

1. **Regeneration** (Scenarios 4–5) — the `regen_rate` / `regen_delay` exports
   exist but nothing reads them yet.
2. **Visual feedback** for both depletion and regrowth (Scenarios 3, 6).

All changes are confined to `scripts/resources/biomass_node.gd` and its tests.
No `UnitBase` or `main.gd` changes are required.

### Confirmed design decisions

1. **Regeneration model: delay-since-last-harvest.** After `regen_delay` seconds
   with no successful extraction, the node regrows at `regen_rate` biomass/sec
   toward `max_biomass`. Every successful `harvest()` resets the countdown, so a
   node under active harvest never regrows, and *any* partially-drained node
   recovers once left alone. A fully-depleted node is simply the extreme case.
   (Rejected: regrow-only-after-full-depletion — partial nodes would never
   recover; and always-regrow — wastes the `regen_delay` export and removes the
   over-harvest punishment window.)
2. **Visuals: shrink + slight fade.** The drawn circle radius scales with the
   biomass ratio down to a small non-zero "husk" floor, so a depleted node stays
   visible and clickable, plus a mild alpha dim when low. (Rejected: fade-only —
   a near-invisible depleted node is easy to miss; color-shift — more tuning,
   less instantly readable.)
3. **Processing model: `_physics_process` accumulator**, consistent with the unit
   harvest loop, deterministic (supports the PRD's lockstep goal), and easy to
   drive in tests by advancing physics frames. (Rejected: a Godot `Timer` node —
   less deterministic, awkward for continuous accrual + delay reset.)

Out of scope: data-driven node stats via JSON (export vars suffice, matching the
existing pattern), auto-resume of a unit after its node regrows (the player
re-issues the harvest command — matches AC5's "when a unit is sent to harvest").

## Component — `BiomassNode` (extend existing script)

### New members

- `signal fully_regenerated` — emitted once when regrowth brings
  `current_biomass` back up to `max_biomass`.
- `var _time_since_harvest: float = 0.0` — seconds since the last successful
  extraction; drives the `regen_delay` gate.
- `var _regen_progress: float = 0.0` — fractional-biomass accumulator, mirroring
  the unit's `_harvest_progress`, so regrowth credits whole biomass units.
- Visual constants: `const MAX_DRAW_RADIUS: float = 20.0` (current outer radius),
  `const MIN_DRAW_RADIUS: float = 6.0` (husk floor), and
  `const MIN_DRAW_ALPHA: float = 0.4` (the alpha multiplier at ratio 0; starting
  tuning value). The inner circle scales proportionally.

Existing members are unchanged: `biomass_changed(current, maximum)`,
`biomass_depleted`, exports `max_biomass=100`, `regen_rate=2.0`,
`regen_delay=10.0`, `harvest_radius=40.0`, and `current_biomass`.

### `harvest(amount)` change

On a **successful** extract (the existing `extracted > 0` path), additionally:
reset `_time_since_harvest = 0.0` and `_regen_progress = 0.0`, call
`set_physics_process(true)`, and `queue_redraw()` (AC3 — the node shrinks as it is
drained). A no-op `harvest()` (amount ≤ 0 or already depleted) must **not** reset
the timer, so the countdown proceeds once a unit stops harvesting.

### `_physics_process(delta)` — regeneration

```gdscript
func _physics_process(delta: float) -> void:
    if current_biomass >= max_biomass:
        return
    _time_since_harvest += delta
    if _time_since_harvest < regen_delay:
        return
    _regen_progress += regen_rate * delta
    var whole := int(_regen_progress)
    if whole <= 0:
        return
    _regen_progress -= float(whole)
    var before := current_biomass
    current_biomass = min(current_biomass + whole, max_biomass)
    if current_biomass == before:
        return
    biomass_changed.emit(current_biomass, max_biomass)
    queue_redraw()
    if current_biomass >= max_biomass:
        _regen_progress = 0.0
        fully_regenerated.emit()
        set_physics_process(false)
```

`_ready` calls `set_physics_process(false)` after seeding `current_biomass =
max_biomass`, so a full node never polls until its first extraction re-enables it.

### Re-harvestable (AC5) — no new code

`is_depleted()` stays `current_biomass <= 0`, so a node becomes non-depleted as
soon as regrowth adds ≥ 1 biomass. `main.gd._get_biomass_node_at_position()`
already filters out depleted nodes on right-click, so a regrown node is
targetable again with no change.

### Visuals — `_draw()`

Extract a pure, testable helper:

```gdscript
func display_radius_for_ratio(ratio: float) -> float:
    return lerpf(MIN_DRAW_RADIUS, MAX_DRAW_RADIUS, clampf(ratio, 0.0, 1.0))
```

`_draw()` computes `ratio = float(current_biomass) / float(max_biomass)` (guard
`max_biomass > 0`), scales both circles by `display_radius_for_ratio(ratio)`, and
multiplies each circle's base alpha (currently 0.8 outer / 0.6 inner) by
`lerpf(MIN_DRAW_ALPHA, 1.0, ratio)` so the node dims as it empties. Making the
radius mapping a pure function mirrors `HealthBar._get_color_for_ratio` and keeps
the visual logic unit-testable without rendering.

## Data flow

`unit.harvest_at(node)` → per-frame `node.harvest(whole)` decrements +
`biomass_changed` + shrink redraw, and resets the node's regen countdown. Unit
leaves / node depletes → no more `harvest()` calls → `_time_since_harvest` climbs
past `regen_delay` → `_physics_process` accrues biomass back up, emitting
`biomass_changed` (grow redraw) each increment and `fully_regenerated` at max.

## Testing (TDD, extend `tests/unit/test_biomass_node.gd`)

Use the existing harness (`add_child_autofree`, `watch_signals`, direct
`current_biomass` assignment, `await get_tree().physics_frame`). Keep regen tests
fast with a small `regen_delay` (e.g. `0.05`) and high `regen_rate` (e.g. `500`).

**Regeneration:**

1. No regrowth before `regen_delay` elapses (advance few frames → unchanged).
2. Regrowth after `regen_delay` (drain, wait past delay, advance → increases).
3. A successful `harvest()` resets the countdown (start regen wait, harvest once,
   confirm the delay restarts and no premature regrowth).
4. **Partial** node recovers (drain to ~50, wait, regrows toward max) — proves the
   delay-since-last-harvest model vs regrow-only-after-full.
5. Regrowth caps at `max_biomass` and never exceeds it.
6. `fully_regenerated` emitted once when reaching max; `biomass_changed` emitted
   on regen increments.
7. Depleted → regrown makes `is_depleted()` false again (AC5).

**Visuals:**

8. `display_radius_for_ratio(1.0) == MAX_DRAW_RADIUS`.
9. `display_radius_for_ratio(0.0) == MIN_DRAW_RADIUS` (husk floor, > 0).
10. Monotonic: radius at a higher ratio ≥ radius at a lower ratio; a mid ratio is
    strictly between the floor and max.

**Regression:** the existing SPI-1382/1385 node tests (harvest extract/clamp/
emit/depleted) must stay green; note that enabling `_physics_process` must not
perturb them (full nodes disable processing; harvested nodes only regrow after
`regen_delay`, which the default 10s keeps well clear of those synchronous tests).
