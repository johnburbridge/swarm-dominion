# Swarm Dominion

A fast-paced real-time strategy game where alien monster factions battle for territorial control.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Godot Engine](https://img.shields.io/badge/Godot-4.3-blue.svg)](https://godotengine.org/)

## Overview

Swarm Dominion offers the strategic depth of classic RTS games with a dramatically lower barrier to entry:

- **5-15 minute matches** - No more 45-minute commitments
- **No dedicated workers** - Every unit can gather or fight
- **No buildings** - Only mobile Mother units that spawn your swarm
- **Free and open source** - Play, modify, and contribute

> "What if StarCraft matches lasted 10 minutes, every unit mattered, and you didn't need to memorize build orders to compete?"

## Game Features

- **Control Point Victory** - Capture and hold strategic points to accumulate Victory Points
- **Unit Progression** - Upgrade generic drones into specialized Hunters, Guardians, or Scouts
- **Supply Management** - Balance army size vs. unit quality
- **Fog of War** - Scout the map to find your enemy
- **Multiplayer** - Competitive 1v1 ranked matchmaking (coming soon)

## Getting Started

### Prerequisites

- [Godot Engine 4.3+](https://godotengine.org/download)
- Git with [Git LFS](https://git-lfs.github.com/) (for asset files)

### Installation

```bash
# Clone the repository
git clone https://github.com/johnburbridge/swarm-dominion.git
cd swarm-dominion

# Pull LFS files (if Git LFS is installed)
git lfs pull

# Open in Godot
godot project.godot
```

### Running Tests

```bash
# Run unit tests (requires Godot in PATH)
godot --headless -s addons/gut/gut_cmdln.gd
```

## Project Structure

```
swarm-dominion/
├── assets/          # Sprites, audio, fonts (Git LFS)
├── scenes/          # Godot scenes (.tscn)
├── scripts/         # GDScript source code
├── data/            # Game configuration (JSON)
├── tests/           # GUT unit tests
├── addons/          # Godot plugins
├── docs/            # Documentation
└── server/          # Dedicated server (future)
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and contribution guidelines.

### Development Roadmap

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Hello Godot - Basic unit movement | Planned |
| M1-M8 | Core gameplay systems | Planned |
| M9-M12 | AI and multiplayer | Planned |
| M13-M16 | Polish and release | Planned |

Full roadmap in [docs/PRD.md](docs/PRD.md).

## Community

- [GitHub Issues](https://github.com/johnburbridge/swarm-dominion/issues) - Bug reports and feature requests
- [GitHub Discussions](https://github.com/johnburbridge/swarm-dominion/discussions) - Questions and ideas

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with [Godot Engine](https://godotengine.org/)
- Testing with [GUT](https://github.com/bitwes/Gut)
- Inspired by classic RTS games

---

*Swarm Dominion is developed by [Spiral House, LLC](https://github.com/johnburbridge)*
