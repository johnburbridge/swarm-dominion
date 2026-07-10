# Mother Unit — Scene, Stats & Slow Movement — Design (SPI-1421)

**Issue:** [SPI-1421](https://linear.app/spiral-house/issue/SPI-1421) · Milestone M4 (Mothers & Spawning) · 3 pts · High
**Parent epic:** SPI-1335 · **Status:** Approved 2026-07-10

## Purpose

Introduce the Mother: a large, high-HP, slow command unit that cannot harvest,
is never auto-targeted, but is selectable and movable like any other unit. It is
the anchor of a player's swarm and the foundation for the rest of M4 — spawning
(SPI-1422), the spawn UI (SPI-1423), rally points (SPI-1424), and the spawn
animation (SPI-1425). This story delivers only the unit itself: scene, stats,
movement, and the behavioral exclusions (no harvest, no auto-attack, not
auto-targeted). No spawning yet.

## Scope

Most of the Mother's behavior is already provided by `UnitBase` and by the
data-driven stat loader — the design leans on that rather than adding code:

- **Movement, health, selection, animation, stat-loading** are inherited from
  `UnitBase` unchanged.
- **Cannot auto-attack** falls out of data: the `mother` stats entry has no
  `attack_range`, so `attack_range` defaults to `0.0`, and
  `UnitBase._setup_attack_area()` returns early — no attack `Area2D` is built,
  so the Mother never detects or engages enemies.
- **Cannot harvest** falls out of data: the `mother` entry has no
  `harvest_speed`, so `harvest_speed` defaults to `0.0`, and
  `UnitBase.harvest_at()` returns early (`if harvest_speed <= 0.0: return`) —
  the Mother stays in its current state and never enters `HARVESTING`.

The two things that need real work:

1. **A `MotherUnit` subclass** to hold Mother-specific behavior now (the
   auto-target exclusion) and in later M4 stories (spawning, rally).
2. **A "never auto-targeted" hook on `UnitBase`.** Today, an enemy unit's
   attack `Area2D` adds *any* opposing `UnitBase` on the body collision layer to
   its `_enemies_in_range`, so enemy drones would auto-attack a Mother. A small,
   overridable predicate fixes this without disturbing drone behavior.

### Confirmed design decisions

1. **`MotherUnit extends UnitBase` subclass** (not a plain scene that only sets
   `unit_type`). The subclass is the natural, discoverable home for the
   auto-target override now and for `spawn_unit()` / rally state in SPI-1422–1424.
   (Rejected: plain `UnitBase` scene with an exported `unit_type = "mother"` —
   leaves nowhere clean to hang the auto-target override or later spawn logic.)
2. **"Not auto-targeted" via an `is_auto_targetable()` predicate on `UnitBase`**
   (default `true`; `MotherUnit` overrides to `false`). The enemy-detection path
   skips units that answer `false`, so they are never enlisted as targets.
   (Rejected: moving the Mother to a different physics collision layer — it would
   also hide the Mother from *future* manual targeting and from other point/area
   queries, and spreads the "is this a Mother?" decision across scene layer
   config instead of one code predicate.)
3. **Visual: reuse `drone_frames.tres` at `scale (2, 2)` plus a distinct tint**,
   with a larger collision shape. Placeholder-era art; a 2× drone silhouette
   reads clearly as "bigger unit" and keeps the story focused on behavior.
   (Rejected: authoring new Mother art — out of proportion to a 3-pt behavior
   story and to the current placeholder art level.)
4. **Test harness spawns one player Mother** (team 1), behind the player drones.
   Enough to satisfy "appears when the scene loads" and to exercise
   selection/movement by hand. (Rejected: also spawning an enemy Mother — adds
   nothing testable for this story and clutters the harness.)

Out of scope: spawning units, spawn UI, rally points, spawn animation (later M4
stories); manual targeting of the Mother by the player (PRD future work); supply
mechanics (M5, though the `base_supply` stat sits unused in the data for now).

## Component — `UnitBase` (shared, minimal change)

Add one overridable predicate and consult it on the enemy-detection path.

```gdscript
## Whether this unit may be chosen as an automatic attack target by enemies.
## Mothers override this to false (they must be targeted manually — future work).
func is_auto_targetable() -> bool:
	return true
```

`_on_body_entered_attack_range(body)` gains a guard so non-auto-targetable
bodies are never enlisted:

```gdscript
func _on_body_entered_attack_range(body: Node2D) -> void:
	if (
		body is UnitBase
		and body != self
		and body.team_id != team_id
		and not body._is_dead
		and body.is_auto_targetable()
	):
		_enemies_in_range.append(body)
```

Because a non-targetable unit is never added to `_enemies_in_range`,
`_try_acquire_target()` already cannot pick it. No change is required there; the
single guard in `_on_body_entered_attack_range` is sufficient. (A unit already
in range when it *becomes* non-targetable is not a scenario in this milestone —
`is_auto_targetable()` is constant per type.)

Default `true` means drones, hunters, guardians, and scouts are unaffected — a
pure regression no-op for every existing unit.

## Component — `MotherUnit` (new: `scripts/units/mother_unit.gd`)

```gdscript
class_name MotherUnit extends UnitBase
## The Mother: large, slow, high-HP command unit. Cannot harvest and cannot
## auto-attack (both fall out of its stats having no harvest_speed/attack_range).
## Never auto-targeted by enemies. Spawns units in a later M4 story (SPI-1422).


func _init() -> void:
	unit_type = "mother"


func is_auto_targetable() -> bool:
	return false
```

Setting `unit_type` in `_init()` (before `UnitBase._ready()` runs `_load_stats()`)
ensures the mother stats are loaded. The scene also sets `unit_type = "mother"`
as an exported value for clarity; `_init` guarantees correctness even if a
`MotherUnit` is constructed in code without the scene.

## Component — `mother.tscn` (new: `scenes/units/mother.tscn`)

Mirror `drone.tscn`, with these differences:

- Root `CharacterBody2D` named `Mother`, `script = mother_unit.gd`.
- `AnimatedSprite2D` using `drone_frames.tres`, `scale = Vector2(2, 2)`,
  `animation = &"idle"`.
- `CollisionShape2D` with a `CircleShape2D` of `radius = 32.0` (drone is 16).
- `HealthBar` instance (as in `drone.tscn`).
- **No** `HarvestIndicator` instance (the Mother cannot harvest).
- Exported `unit_type = "mother"` on the root for readability.

The `team_id` and `modulate` tint are set by the spawner (see below), matching
how drones are configured in `_spawn_test_units()`.

## Component — `main.gd._spawn_test_units()` (modify)

Add a `MotherScene` preload alongside `DroneScene`, and spawn one player Mother
after the player drones:

```gdscript
const MotherScene = preload("res://scenes/units/mother.tscn")
```

```gdscript
	var mother := MotherScene.instantiate()
	mother.team_id = 1
	mother.position = Vector2(760, 400)
	mother.modulate = Color(0.6, 1.0, 0.6)
	add_child(mother)
	print("Spawned player Mother")
```

Position it behind/above the player drone cluster (drones occupy ~y 480–600)
so it is visible and not overlapping. Tint is a slightly deeper green than the
drones' `Color(0.7, 1.0, 0.7)` to distinguish the Mother while keeping team read.

## Data flow

`MotherScene.instantiate()` → `_init` sets `unit_type = "mother"` →
`UnitBase._ready()` loads mother stats (HP 500, speed 50), joins `"units"`,
builds the selection circle, and **skips** the attack area (range 0) →
`_setup_attack_area` no-op. Player clicks/drag-selects it through the existing
`SelectionManager` path (team 1, layer 1, in `"units"`). Right-click empty ground
→ `move_to` → `MOVING` at speed 50. Right-click a biomass node → `harvest_at`
returns immediately (harvest_speed 0), Mother stays IDLE. Enemy units' attack
areas call `_on_body_entered_attack_range(mother)`, which now skips it
(`is_auto_targetable()` false), so no enemy ever auto-attacks it.

## Testing (TDD, new `tests/unit/test_mother_unit.gd`)

Use the existing GUT harness patterns (`add_child_autofree`, `watch_signals`,
`await get_tree().physics_frame`). Instantiate via the scene
(`preload("res://scenes/units/mother.tscn").instantiate()`) so `_ready`/stat
loading runs, mirroring how drone-based tests set up units.

**Stats & identity:**

1. Mother loads `mother` stats: `max_health == 500`, `current_health == 500`,
   `move_speed == 50`.
2. `unit_type == "mother"`.
3. `is_auto_targetable()` returns `false`.

**Behavioral exclusions:**

4. Cannot harvest: after `harvest_at(node)` with a non-depleted node,
   `is_harvesting()` is `false` and the state remains `IDLE`
   (`harvest_speed == 0.0`).
5. No attack area: the Mother has no child `Area2D` named `AttackRange`
   (`attack_range == 0.0` → `_setup_attack_area` skipped), confirming it cannot
   auto-attack.

**Movement & selection (inherited, verified for the Mother):**

6. `move_to(far_point)` sets state to `MOVING`; after advancing physics frames
   the Mother's position moves toward the target (proves slow movement works via
   the inherited path).
7. `set_selected(true)` makes the selection circle visible; `set_selected(false)`
   hides it.

**Auto-target exclusion (the shared-code change):**

8. A drone's `_on_body_entered_attack_range(mother)` does **not** add the Mother
   to the drone's `_enemies_in_range` (drone and Mother on opposing teams).
9. Control: a drone's `_on_body_entered_attack_range(enemy_drone)` **does** add a
   normal enemy drone (proves the guard is specific to non-targetable units, not
   a blanket break).

**Regression:** existing `UnitBase`/drone tests stay green — `is_auto_targetable()`
defaults to `true`, so drone auto-attack and target acquisition are unchanged.

## Files touched

- Create: `scripts/units/mother_unit.gd`
- Create: `scenes/units/mother.tscn`
- Modify: `scripts/units/unit_base.gd` (add `is_auto_targetable()`, guard
  `_on_body_entered_attack_range`)
- Modify: `scripts/main.gd` (`MotherScene` preload + spawn one player Mother)
- Create: `tests/unit/test_mother_unit.gd`
- No change: `data/unit_stats.json` (the `mother` entry already exists)
