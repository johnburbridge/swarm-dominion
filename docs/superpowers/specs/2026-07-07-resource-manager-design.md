# ResourceManager Autoload — Design (SPI-1383)

**Issue:** [SPI-1383](https://linear.app/spiral-house/issue/SPI-1383) · Milestone M3 (Resource Gathering) · 2 pts
**Status:** Approved 2026-07-07

## Purpose

Own the per-team biomass ledger: a single autoload that tracks how much biomass
each team has, and is the one place resources are added, spent, and queried.
Foundational for the rest of M3 — the gather loop (SPI-1385/1386) and counter UI
(SPI-1384) build on it.

## Approach

Standalone `ResourceManager` autoload backed by a `{ team_id: int → biomass: int }`
dictionary. Rejected alternatives: folding biomass into `GameManager.players`
(couples resource logic to game-state flow) and per-player scene-tree nodes
(overkill). A dedicated autoload keeps one clear responsibility and is trivially
testable.

## File & registration

- `scripts/autoload/resource_manager.gd`
- Registered in `project.godot` `[autoload]` after EventBus, GameManager,
  AudioManager, SelectionManager.

## Data model

```gdscript
const STARTING_BIOMASS: int = 0
var _biomass: Dictionary = {}   # team_id: int -> biomass: int
```

Unknown teams read as `STARTING_BIOMASS` (lazy init — no registration step).

## API

```gdscript
func get_resources(team_id: int) -> int            # current amount (0 if unknown)
func can_afford(team_id: int, amount: int) -> bool # current >= amount
func add_resources(team_id: int, amount: int) -> void   # emits resources_changed on change
func spend_resources(team_id: int, amount: int) -> bool # false if unaffordable; emits on success
func reset() -> void                               # clears ledger (match restart / test isolation)
```

## Data flow

On a successful `add`/`spend`, emit `EventBus.resources_changed(team_id, new_amount)`
— the signal the counter UI (SPI-1384) will consume. Per-team isolation is
inherent to the dictionary.

## Decisions

1. `team_id` fills the signal's `player_id` slot — same concept in this codebase.
2. Non-positive amounts are guarded: `add` of ≤0 is a no-op (no emit); `spend`
   of ≤0 returns `false`.
3. `get_resources()` and `reset()` are added beyond the ACs — `get_resources`
   is needed by UI/tests; `reset` gives GUT clean state between tests (autoloads
   persist across a run).

## Acceptance criteria (from SPI-1383)

1. Track biomass per team (team 1 add doesn't affect team 2).
2. `add_resources(team, 10)` from 0 → 10, emits `resources_changed`.
3. `spend_resources(team, 30)` from 50 → 20, emits `resources_changed`.
4. Cannot overspend: `spend_resources(team, 30)` with 20 → returns false, stays 20.
5. `can_afford`: 50 vs 30 → true; 50 vs 60 → false.

## Testing

`tests/unit/test_resource_manager.gd` (GUT), `before_each` calls `reset()`:
all five ACs, plus per-team isolation, `get_resources`, non-positive guards, and
`resources_changed` emission (via `watch_signals(EventBus)`).
