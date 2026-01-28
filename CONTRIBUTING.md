# Contributing to Swarm Dominion

Thank you for your interest in contributing to Swarm Dominion! This document provides guidelines for contributing to the project.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Types of Contributions

We welcome:

- **Code** - Bug fixes, features, optimizations
- **Art Assets** - Sprites, animations, UI elements
- **Audio** - Sound effects, music
- **Documentation** - Guides, tutorials, wiki content
- **Testing** - Bug reports, playtesting feedback
- **Translations** - Localization to other languages

## Getting Started

### Prerequisites

- [Godot Engine 4.3+](https://godotengine.org/download)
- [Git](https://git-scm.com/) with [Git LFS](https://git-lfs.github.com/)
- Python 3.8+ (for linting tools)

### Development Setup

```bash
# Clone the repository
git clone https://github.com/johnburbridge/swarm-dominion.git
cd swarm-dominion

# Install Git LFS and pull assets
git lfs install
git lfs pull

# Install linting tools (optional but recommended)
pip install gdtoolkit

# Open project in Godot
godot project.godot
```

### Running Tests

```bash
# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd

# Run specific test file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_example.gd
```

### Code Linting

```bash
# Check GDScript formatting
gdformat --check scripts/

# Run linter
gdlint scripts/
```

## Development Workflow

1. **Check existing issues** - Look for related issues or discussions
2. **Create an issue** - Describe what you want to work on
3. **Fork the repository** - Create your own copy
4. **Create a branch** - Use descriptive names:
   - `feature/unit-pathfinding`
   - `bugfix/selection-crash`
   - `docs/tutorial-update`
5. **Make changes** - Follow the style guide below
6. **Test your changes** - Run tests and playtest
7. **Submit a PR** - Reference the related issue

## Code Style Guide

### GDScript Conventions

```gdscript
# Classes use PascalCase
class_name UnitController extends Node2D

# Constants use UPPER_SNAKE_CASE
const MAX_HEALTH: int = 100
const MOVE_SPEED: float = 200.0

# Variables and functions use snake_case
var current_health: int = MAX_HEALTH
var is_selected: bool = false

# Private members use leading underscore
var _internal_state: String

# Always use type hints
func take_damage(amount: int) -> void:
    current_health -= amount
    if current_health <= 0:
        _die()

func _die() -> void:
    queue_free()
```

### File Organization

- **Scenes** (`scenes/`) - One scene per file, grouped by type
- **Scripts** (`scripts/`) - Organized by domain (units, systems, ui)
- **Assets** (`assets/`) - Grouped by type (sprites, audio, fonts)

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(units): add pathfinding to drone movement
fix(ui): resolve health bar not updating
docs(readme): add installation instructions
test(combat): add damage calculation tests
refactor(systems): simplify resource collection
```

## Pull Request Guidelines

### PR Checklist

- [ ] Code follows the style guide
- [ ] Tests pass (`godot --headless -s addons/gut/gut_cmdln.gd`)
- [ ] Linting passes (`gdformat --check . && gdlint .`)
- [ ] Changes are documented
- [ ] Related issue is linked

### PR Description Template

```markdown
## Summary
Brief description of changes.

## Related Issues
Fixes #123

## Testing
How was this tested?

## Screenshots
(If applicable)
```

## Asset Contributions

### Images

- Format: PNG (with transparency where needed)
- Resolution: Power of 2 preferred (64x64, 128x128, etc.)
- Style: Match existing art direction

### Audio

- Format: OGG Vorbis for music, WAV for short SFX
- Normalize audio levels
- Provide licensing information

### Licensing

All contributions must be compatible with the MIT License. By submitting a PR, you agree that your contributions will be licensed under MIT.

## Questions?

- Open a [GitHub Discussion](https://github.com/johnburbridge/swarm-dominion/discussions)
- Check existing issues and documentation

Thank you for contributing!
