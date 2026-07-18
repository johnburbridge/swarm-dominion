# Map-Definition Format + Loader — Design (SPI-1443)

**Issue:** [SPI-1443](https://linear.app/spiral-house/issue/SPI-1443) · Milestone: Maps & Level Design (epic SPI-1442) · 5 pts
**Parent epic:** SPI-1442 · **Status:** Approved 2026-07-17

## Purpose

Make maps data-driven. Today every entity in the primary scene is hardcoded at
literal coordinates in `scripts/main.gd` (`_spawn_test_units`,
`_spawn_biomass_nodes`), and `data/map_definitions/` is an empty placeholder.
This story adds a JSON map-definition format and a loader that instantiates a
map from it, so maps are authored as data — consistent with the project's
existing data-driven pattern (`data/unit_stats.json`, `data/upgrade_costs.json`).

This is foundational: it unblocks the greybox map (SPI-1444) and the competitive
maps (SPI-1448), and it gives M7 control points (SPI-1342) a placement channel.

## Scope decisions

Confirmed with the product owner:

1. **Control points: full schema now, placeholder instantiation.** The map
   schema carries the complete §2.6 control-point definition
   (`position`, `capture_radius`, `vp_weight`) even though the real
   `ControlPoint` scene does not exist yet (M7 / SPI-1342). The loader
   instantiates a lightweight placeholder (`Marker2D` + `Area2D`) into a
   `"control_points"` group. M7 later swaps only that placeholder branch —
   the schema and parse layer stay untouched.
2. **Optional `units` array in the schema** so `main.gd` can fully delegate
   entity placement (satisfies the "no longer hardcodes" AC). Real competitive
   maps leave it empty (units come from Mothers in-game); the test map uses it
   to reproduce today's combat fixtures.
3. **Sample map is symmetric** — it adds a team-2 Mother (today the scene has
   only a player Mother). An idle enemy Mother is harmless for the test scene
   and makes the map representative.

Out of scope (owned elsewhere): real `ControlPoint` scene + capture logic + VP
accrual (M7 / SPI-1342); a dedicated competitive greybox scene (SPI-1444, blocked
by this); palette-swap team color (SPI-1436) — the loader keeps the existing
temporary `modulate` tint as a stopgap.

## Format — JSON under `data/map_definitions/`

Loaded the same way as `unit_stats.json`: `FileAccess.open` → `JSON.parse` →
`push_warning` + sensible defaults on failure.

Sample `data/map_definitions/test_arena.json`:

```json
{
  "name": "Test Arena",
  "bounds": { "x": 0, "y": 0, "width": 1920, "height": 1080 },
  "spawn_points": [
    { "team_id": 1, "position": [760, 400] },
    { "team_id": 2, "position": [1160, 400] }
  ],
  "biomass_nodes": [
    { "position": [500, 400] },
    { "position": [950, 300] },
    { "position": [950, 700] },
    { "position": [1400, 400] }
  ],
  "control_points": [
    { "id": "center", "position": [960, 540], "capture_radius": 96, "vp_weight": 3 }
  ],
  "units": [
    { "type": "drone", "team_id": 1, "position": [700, 480] },
    { "type": "drone", "team_id": 1, "position": [760, 540] },
    { "type": "drone", "team_id": 1, "position": [820, 480] },
    { "type": "drone", "team_id": 1, "position": [760, 600] },
    { "type": "drone", "team_id": 2, "position": [1100, 480] },
    { "type": "drone", "team_id": 2, "position": [1160, 540] },
    { "type": "drone", "team_id": 2, "position": [1220, 480] }
  ]
}
```

Field reference:

| Field | Meaning | Default if missing |
|-------|---------|--------------------|
| `name` | Display name | `""` |
| `bounds` | Map size `{x, y, width, height}` → `Rect2` (camera limits) | `Rect2()` (zero) |
| `spawn_points[]` | `{team_id, position:[x,y]}` — one Mother per entry (§2.4) | `[]` |
| `biomass_nodes[]` | `{position:[x,y]}` | `[]` |
| `control_points[]` | `{id, position:[x,y], capture_radius, vp_weight}` (§2.6) | `[]` |
| `units[]` | Optional `{type, team_id, position:[x,y]}` test/debug units | `[]` |

Per-entry defaults: `control_point.capture_radius` → `96`, `vp_weight` → `1`,
`id` → `""`; `unit.type` → `"drone"`, `team_id` → `0`.

## Component 1 — `MapDefinition` (parse layer)

`class_name MapDefinition extends RefCounted` in
`scripts/systems/map_definition.gd`. Pure data — no scene tree — so it is fully
headless-testable.

**API**

- `static func from_file(path: String) -> MapDefinition` — opens the file,
  parses JSON, delegates to `from_dict`. On a missing file or unparseable JSON:
  `push_warning` and return `null`.
- `static func from_dict(data: Dictionary) -> MapDefinition` — builds a validated
  definition from an already-parsed dictionary (keeps parsing and validation
  separately testable, and lets tests skip disk I/O).

**Fields**

- `map_name: String`
- `bounds: Rect2`
- `spawn_points: Array[Dictionary]`
- `biomass_nodes: Array[Dictionary]`
- `control_points: Array[Dictionary]`
- `units: Array[Dictionary]`

**Soft-handling** (mirrors `unit_base._load_stats`):

- Missing top-level array → default to `[]` (definition still valid).
- Missing `bounds` → `Rect2()`.
- A malformed entry (e.g. a biomass node with no `position`, or a non-array
  `position`) → skip that entry with a `push_warning`, keep the siblings.
- Missing per-entry optional fields → filled with the per-entry defaults above.
- Never crashes on bad data; the worst case is an emptier-than-authored map plus
  warnings.

A private `_parse_vec2(value) -> Variant` helper converts a `[x, y]` array to
`Vector2`, returning `null` for malformed input so the caller can skip the entry.

## Component 2 — `MapLoader` (instantiation layer)

`class_name MapLoader extends RefCounted` in
`scripts/systems/map_loader.gd`. A thin, tree-touching adapter over a parsed
`MapDefinition`.

**API**

```gdscript
static func populate(definition: MapDefinition, parent: Node) -> Dictionary
```

Preloads the entity scenes (`drone.tscn`, `mother.tscn`, `biomass_node.tscn`) and
instantiates:

- **Spawn points** → one Mother per entry (`team_id`, `position`, temp tint),
  `add_child` to `parent`.
- **Biomass nodes** → a `BiomassNode` per entry at `position`.
- **Control points** → a placeholder: `Marker2D` at `position` with a child
  `Area2D` + `CircleShape2D` of radius `capture_radius`; `vp_weight` and `id`
  stored via `set_meta`; added to the `"control_points"` group. (M7 swaps this
  for the real `ControlPoint` scene.)
- **Units** (optional) → a unit per entry by `type` (`drone` for now;
  unknown type → `push_warning`, skip), `team_id`, `position`, temp tint.

**Team tint** — a private `_apply_team_tint(node, team_id)` reproduces the current
`modulate` convention (team 1 greenish, team 2 reddish, else white). Documented as
a stopgap for SPI-1436's palette-swap shader.

**Return value** — a `Dictionary` of the spawned nodes so callers can grab
references without re-querying the tree:

```gdscript
{ "mothers": Array, "biomass_nodes": Array, "control_points": Array, "units": Array }
```

The loader is deliberately camera-agnostic: `bounds` is consumed by `main.gd`,
not here.

## Component 3 — `main.gd` integration

Delete `_spawn_test_units()` and `_spawn_biomass_nodes()`. `_ready()` loads the
definition instead:

```gdscript
func _ready() -> void:
    print("Swarm Dominion initialized")
    _load_map("res://data/map_definitions/test_arena.json")
    _minimap.set_camera(_camera)


func _load_map(path: String) -> void:
    var definition := MapDefinition.from_file(path)
    if definition == null:
        push_warning("Main: failed to load map '%s'" % path)
        return
    var loaded := MapLoader.populate(definition, self)
    _player_mother = _find_player_mother(loaded["mothers"])
    _apply_camera_bounds(definition.bounds)
```

- `_find_player_mother(mothers: Array) -> MotherUnit` returns the first Mother
  with `team_id == PLAYER_TEAM_ID` (or `null`).
- `_apply_camera_bounds(bounds: Rect2)` sets the `Camera2D` limit properties from
  `bounds` when it is non-empty (keeps camera logic in `main.gd`).

## Data flow

`main._ready()` → `MapDefinition.from_file(path)` (parse + validate, pure) →
`MapLoader.populate(definition, main)` (instantiate entities into the scene, return
spawned refs) → `main` picks the player Mother and applies camera bounds. Bad
data degrades gracefully to warnings + a partial map.

## Testing (TDD, red → green → refactor; 3-agent relay per project convention)

Harness patterns mirror `tests/unit/test_engage_unit.gd` /
`tests/unit/test_unit_harvest.gd`.

**`test_map_definition.gd`** (new, pure/headless — no tree needed):

1. `from_dict` with a valid dict → correct `map_name`, `bounds` (Rect2), and
   `spawn_points`/`biomass_nodes`/`control_points`/`units` counts.
2. Control-point parsing → `capture_radius` and `vp_weight` read correctly;
   missing optional fields → defaults (`96`, `1`).
3. `from_file` on the real `test_arena.json` parses end-to-end (non-null, expected
   counts).
4. Unparseable JSON (via a temp file, or a `from_file` on a bogus path) → returns
   `null`, no crash.
5. Missing top-level arrays → default to empty, definition still valid.
6. A malformed entry (biomass node without `position`) → skipped; sibling valid
   entries retained.

**`test_map_loader.gd`** (new — `add_child_autofree` a parent `Node2D`):

1. `populate` spawns the correct number of biomass nodes as children.
2. One Mother per spawn point, each with the right `team_id` and `position`.
3. Control-point placeholders added to the `"control_points"` group, each with a
   `capture_radius`-sized shape and `vp_weight` in metadata.
4. Optional units spawned with correct `type`/`team_id`/`position`; unknown type
   skipped.
5. Returned dict contains the spawned nodes under
   `mothers`/`biomass_nodes`/`control_points`/`units`.

**Reminder (project gotcha):** new `class_name` files need
`godot --headless --import` before other scripts/tests can resolve the types, and
GUT silently skips a parse-errored test file while still reporting green — after
adding each test file, confirm the Scripts/Tests counts rose (grep for the
filename), don't trust the summary alone.

## File summary

| File | Change |
|------|--------|
| `scripts/systems/map_definition.gd` | New — parse/validate layer (`MapDefinition`) |
| `scripts/systems/map_loader.gd` | New — instantiation layer (`MapLoader`) |
| `data/map_definitions/test_arena.json` | New — sample definition |
| `scripts/main.gd` | Replace hardcoded spawns with map load |
| `tests/unit/test_map_definition.gd` | New — parse-layer tests |
| `tests/unit/test_map_loader.gd` | New — instantiation-layer tests |
