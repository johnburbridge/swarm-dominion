# Mother Rally Point — Design (SPI-1424)

**Issue:** [SPI-1424](https://linear.app/spiral-house/issue/SPI-1424) · Parent: SPI-1335 (M4 Mothers & Spawning) · 3 pts
**Status:** Approved 2026-07-23
**Depends on:** SPI-1422 (spawn factory), SPI-1423 (spawn UI) — both merged.

## Purpose

Units spawned from a Mother currently appear in a fan ring on top of the Mother
(`MotherUnit.spawn_unit`) and just sit there. This story lets the player set a **rally
point** so spawned units automatically walk to a chosen location instead of piling up —
the standard RTS production-building affordance, adapted to our mobile Mother.

## Scope decisions

Confirmed with the product owner:

1. **Rally-set interaction = HUD button *and* hotkey, sharing one arming state.** A "Set
   Rally" button on the existing spawn panel and the **R** key both *arm* rally placement;
   the next left-click on the map sets the point. Right-click is deliberately not used — it
   already moves the mobile Mother (and harvests/engages). Arming (rather than a direct
   click-to-set) keeps rally distinct from selection and move.
2. **Default rally = just below the Mother.** With no explicit rally, spawned units move to
   `Mother.position + DEFAULT_RALLY_OFFSET` (`Vector2(0, 96)`), so they clear the Mother's
   body instead of stacking. This satisfies the "sensible default near the Mother" AC.
3. **Marker = drawn ring + crosshair in the team color** via `_draw()` — no art asset
   dependency (consistent with how the project draws the selection circle / minimap).

Out of scope: rally onto a unit/node for auto-harvest or auto-follow (only a ground point);
queued/multi-point rally; persisting rally across Mother death (the Mother and its marker are
freed together). Rally is a single `Vector2` per Mother.

## Components

### 1. `RallyMarker` (new) — `scripts/ui/rally_marker.gd`

`class_name RallyMarker extends Node2D`. Draws a small ring + crosshair via `_draw()`:

- `set_team_color(color: Color)` — stores the color and calls `queue_redraw()`.
- `_draw()` — `draw_arc()` for the ring (radius ~10 px) + two short crosshair lines, in the
  team color.

Pure visual, no logic. Instantiated by the Mother in world space.

### 2. `MotherUnit` (modify) — `scripts/units/mother_unit.gd`

Rally state and behavior live on the Mother (it owns the point and the marker):

**Constants**

```gdscript
## Offset from the Mother's center for the default rally (no explicit point set):
## directly below, clear of the Mother's body (radius 32) plus a Drone's radius.
const DEFAULT_RALLY_OFFSET: Vector2 = Vector2(0, 96)
## Radius of the drawn rally marker, passed to RallyMarker.
const RALLY_MARKER_RADIUS: float = 10.0
```

**State**

```gdscript
var _rally_point: Vector2 = Vector2.ZERO
var _has_rally: bool = false
var _rally_marker: RallyMarker = null
```

**API**

- `set_rally_point(pos: Vector2) -> void` — stores `pos`, sets `_has_rally = true`, moves the
  marker there, and shows it if the Mother is currently selected.
- `has_rally() -> bool`, `get_rally_point() -> Vector2` — accessors.
- `get_effective_rally() -> Vector2` — returns `_rally_point` if `_has_rally`, else
  `position + DEFAULT_RALLY_OFFSET`. This is the single source of truth for where a spawned
  drone goes.

**Marker ownership** — created in `_ready()` (after `super._ready()`): a `RallyMarker`
instance added as a child with `top_level = true` (so its transform is world-space, not
inherited from the Mother — the rally point stays put when the Mother moves), tinted via
`TeamColors.color_for(team_id)`, `visible = false`. Being a child, it is freed automatically
when the Mother is freed (covers the death case with no extra code).

**Selection override** — override `set_selected(selected)` to call `super.set_selected()`
then update marker visibility: visible only when `selected and _has_rally`. Deselecting hides
the marker; `_rally_point`/`_has_rally` are retained (marker lifecycle AC).

**Spawn change** — in `spawn_unit()`, after the drone is positioned in its fan-ring spot and
added to the tree, issue `drone.move_to(get_effective_rally())`. One added line; the existing
ring placement stays as the *spawn* position, and the drone then walks to the rally.

### 3. `SpawnPanel` (modify) — `scripts/ui/spawn_panel.gd` + `scenes/ui/spawn_panel.tscn`

- Scene: add a second `Button` named `RallyButton` (text "Set Rally") beside `SpawnButton`;
  widen the panel to fit both. Rally is free, so the button is enabled whenever a Mother is
  selected (never greyed by cost).
- Script: new signal `signal rally_set_requested`; connect `RallyButton.pressed` →
  emit it. The panel does not itself know the map location — it only requests arming;
  `main.gd` handles the placement click. `_refresh()` still governs only the spawn button's
  cost state.

### 4. `main.gd` (modify) — arming + placement

- New field `_rally_set_pending: bool = false`.
- Arm from the hotkey: in `_unhandled_input`, handle the new `set_rally` action — arm only
  when the current selection contains a Mother on the player's team (else ignore, so R is
  inert with no Mother selected).
- Arm from the panel: connect `SpawnPanel.rally_set_requested` (in `_ready`) to set
  `_rally_set_pending = true`.
- Consume on the next left-click: in `_handle_click_select` (where `_attack_move_pending` is
  already consumed at the top), if `_rally_set_pending`, call a new
  `_issue_set_rally(get_global_mouse_position())` and disarm — before any selection logic, so
  the click sets rally instead of selecting. `_issue_set_rally` sets the rally on every
  selected player Mother at the click position.

The armed click ignores whatever is under the cursor (matches attack-move: it commits a
location, not a target).

### 5. `project.godot` (modify)

Add a `set_rally` input action bound to **R** (keycode 82) — free (WASD camera uses W/A/S/D,
attack-move uses A; R is unused). Follows the existing `attack_move` action's structure.

## Interaction flow

```
Select Mother ──► SpawnPanel shows [Spawn Drone] [Set Rally]
      │
      ├── press R  ──────────────┐  (armed only if a player Mother is selected)
      ├── click "Set Rally" ─────┤──► _rally_set_pending = true
      │                          │
      └── next LEFT-CLICK on map ─► _issue_set_rally(mouse):
                                       set_rally_point on each selected player Mother
                                       marker appears at the point (Mother is selected)
                                       _rally_set_pending = false

Spawn Drone ──► drone spawns in fan ring ──► move_to(get_effective_rally())
Deselect Mother ──► marker hidden (rally retained)
Mother dies ──► marker freed with the Mother (child node)
```

## Data flow

`main` arms `_rally_set_pending` (R or panel signal) → next left-click →
`_issue_set_rally` → `Mother.set_rally_point(pos)` (stores point, moves + shows marker) →
on `spawn_unit`, `get_effective_rally()` feeds `drone.move_to(...)`. The Mother is the single
owner of rally state; `main` only supplies the interaction, `SpawnPanel` only requests arming.

## Error / edge handling

- **R with no Mother selected:** ignored (guarded by the selection check) — no arming, no
  state change.
- **Arm, then click on a unit/UI:** the armed left-click sets rally at the location regardless
  of what's under it (like attack-move). (Clicks on the HUD panel itself are consumed by the
  Control and never reach `_unhandled_input`, so pressing "Set Rally" won't also count as the
  placement click.)
- **Multiple Mothers selected:** all get the same rally point; each shows its own marker.
- **No explicit rally:** `get_effective_rally()` returns the just-below-Mother default, so
  `spawn_unit` always issues a valid move (drones never stack on the Mother).
- **Mother moves after rally set:** rally is world-space (marker is `top_level`), so it stays
  where placed; future spawns still target it.
- **Mother death:** marker is a child node → freed automatically; no dangling marker.

## Testing (TDD, red → green → refactor)

**`tests/unit/test_mother_rally.gd`** (new; instantiate a Mother via `add_child_autofree`):

1. `has_rally()` is false initially; `get_effective_rally()` returns
   `position + DEFAULT_RALLY_OFFSET`.
2. `set_rally_point(p)` → `has_rally()` true, `get_rally_point()`/`get_effective_rally()`
   return `p`.
3. `spawn_unit()` with a rally set → the spawned drone's target is the rally point (assert via
   the drone entering MOVING toward `p`, mirroring `test_mother_spawn_drone.gd`'s spawn
   assertions + `test_unit_*` movement checks). Fund the spawn via `ResourceManager` as the
   existing spawn tests do.
4. `spawn_unit()` with **no** rally → the spawned drone's target is the default
   (`position + DEFAULT_RALLY_OFFSET`).
5. Marker visibility: hidden when unselected; after `set_rally_point` + `set_selected(true)`
   visible; `set_selected(false)` hides it but `has_rally()` stays true (retention).

**`tests/unit/test_spawn_panel.gd`** (extend): pressing `RallyButton` emits
`rally_set_requested` (watch the signal); the button is enabled when a Mother is selected
regardless of affordability.

**Input wiring** (`main`): a focused test that, with a player Mother selected and
`_rally_set_pending` armed, a left-click at a position sets that Mother's rally to the click
location — following the harness style of the existing selection/command tests where
feasible; otherwise covered by the manual in-engine check.

**Manual (in-engine):** select the Mother, press R (and separately click Set Rally), click the
map, confirm the marker draws in team color, spawn a drone and watch it walk to the rally;
deselect and confirm the marker hides.

**Project gotchas:** new `class_name` (`RallyMarker`) needs `godot --headless --import` before
other scripts/tests resolve it; GUT silently skips a parse-errored test file while reporting
green — after adding each test file, grep the run log to confirm it actually ran.

## File summary

| File | Change |
|------|--------|
| `scripts/ui/rally_marker.gd` | New — `RallyMarker`, draws ring+crosshair in team color |
| `scripts/units/mother_unit.gd` | Rally state, `set_rally_point`/`get_effective_rally`, marker, spawn move |
| `scripts/ui/spawn_panel.gd` | New `rally_set_requested` signal + RallyButton wiring |
| `scenes/ui/spawn_panel.tscn` | Add `RallyButton`; widen panel |
| `scripts/main.gd` | `_rally_set_pending`, arm via R + panel signal, consume click → set rally |
| `project.godot` | New `set_rally` input action (R) |
| `tests/unit/test_mother_rally.gd` | New — rally state, effective-rally, spawn move, marker rules |
| `tests/unit/test_spawn_panel.gd` | Extend — RallyButton emits `rally_set_requested` |
