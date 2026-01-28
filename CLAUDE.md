# Swarm Dominion

A fast-paced RTS game built with Godot 4.x where alien monster factions battle for territorial control.

## Tech Stack

- **Engine:** Godot 4.3.1
- **Language:** GDScript
- **Testing:** GUT (Godot Unit Testing)
- **Linting:** gdtoolkit (gdformat, gdlint)

## Project Structure

```
scenes/     - Godot scenes (.tscn)
scripts/    - GDScript source code
  autoload/ - Singleton scripts (GameManager, EventBus, etc.)
  systems/  - Core game systems
  units/    - Unit-related scripts
assets/     - Sprites, audio, fonts (Git LFS)
data/       - JSON configuration files
tests/      - GUT unit tests
addons/     - Godot plugins (GUT)
docs/       - Documentation including PRD
```

## Build & Test Commands

```bash
# Open project in Godot
godot project.godot

# Run the game
godot --path . scenes/main/main.tscn

# Run tests (headless)
godot --headless -s addons/gut/gut_cmdln.gd

# Check formatting
gdformat --check scripts/

# Run linter
gdlint scripts/
```

## Architecture Patterns

- **Signal-based communication** - Use signals for loose coupling between systems
- **Autoloads** - GameManager, EventBus, AudioManager as global singletons
- **Component design** - Scenes as reusable components
- **Data-driven** - Unit stats, costs, etc. in JSON files under `data/`

## GDScript Conventions

```gdscript
class_name UnitBase extends CharacterBody2D

const MAX_HEALTH: int = 100      # UPPER_SNAKE_CASE
var current_health: int          # snake_case with type hints
var _private_var: String         # Leading underscore for private

func take_damage(amount: int) -> void:  # Type hints on params and returns
    pass
```

## Game Design Reference

See @docs/PRD.md for full game design including:
- Core game loop (Gather → Decide → Execute → Adapt)
- Unit system (Drone → Hunter/Guardian/Scout → Elite)
- Control point victory mechanics
- Milestones M0-M16

## Common Tasks

**Adding a new unit type:**
1. Create scene in `scenes/units/`
2. Create script extending `UnitBase` in `scripts/units/`
3. Add stats to `data/unit_stats.json`
4. Register in relevant systems

**Adding a new system:**
1. Create script in `scripts/systems/`
2. If global, add as autoload in `project.godot`
3. Connect to EventBus for cross-system communication

## Gotchas

- Godot 4 uses `.godot/` for cache (not `.import/`)
- Scenes are text-based `.tscn` files (git-friendly)
- Use `@onready` for node references, not `$Node` in `_ready()`
- Signals should be defined at top of class
- Export presets need to be configured before CI can build

## Linear Integration

**Team:** Spiral House
- ID: `03ee7cf5-773e-4f53-bc0d-2e5e4d3bc3bc`

**Project:** Swarm Dominion
- ID: `c801f604-fdc4-45a0-b525-b85bb6e91704`

**Issue Statuses:**

| Status | ID | Type |
|--------|-----|------|
| Backlog | `1e7bd879-6685-4d94-8887-b7709b3ae6e8` | backlog |
| Todo | `fc814d1f-22b5-4ce6-8b40-87c1312d54ba` | unstarted |
| In Progress | `a433a32b-b815-4e11-af23-a74cb09606aa` | started |
| In Review | `8d617a10-15f3-4e26-ad28-3653215c2f25` | started |
| Done | `3d267fcf-15c0-4f3a-8725-2f1dd717e9e8` | completed |
| Canceled | `a2581462-7e43-4edb-a13a-023a2f4a6b1e` | canceled |
| Duplicate | `3f7c4359-7560-4bd9-93b7-9900671742aa` | canceled |
