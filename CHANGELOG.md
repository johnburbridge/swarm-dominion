# Changelog

All notable changes to Swarm Dominion will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

**Project scaffolding**
- Initial project structure
- Product Requirements Document (PRD)
- Contributing guidelines
- Code of Conduct
- Security policy

**Milestone 0 - Hello Godot**
- Display a unit sprite on the game scene (SPI-1348)
- Move a unit to a clicked map location (SPI-1349)
- Smooth camera follow for unit movement (SPI-1350)
- Walking animation and grid background (SPI-1351)

**Milestone 1 - Basic Combat**
- Health system with HP, damage, and death mechanics (SPI-1362)
- Health bar UI above each unit, with 5-tier color thresholds (SPI-1363)
- Auto-attack behavior for idle units with an enemy in range (SPI-1364)
- Death animation and removal of dead units from the scene (SPI-1365)

**Milestone 2 - Selection & Control**
- Single-unit selection by click (SPI-1368)
- Drag-box multi-selection (SPI-1370)
- Attack-move command via A + click (SPI-1371)
- Control groups: Ctrl+N to assign, N to recall, double-tap to snap camera (SPI-1372)
- Basic minimap with coordinate projection and rendering (SPI-1373)
- ENGAGING state and right-click-enemy engage with spread offsets (SPI-1381)

**Milestone 3 - Resource Gathering**
- BiomassNode scene, and biomass nodes placed on the test map (SPI-1382)
- ResourceManager autoload tracking per-team biomass with a `resources_changed` signal (SPI-1383)
- HARVESTING state and gather behavior, with a `BiomassNode.harvest()` extract API (SPI-1385)
- Right-click a biomass node to dispatch a harvest command (SPI-1386)
- Resource counter UI on the HUD (SPI-1384)
- Harvest indicator: a biomass-green pip shown above units while harvesting (SPI-1387)
- Biomass nodes regenerate after a harvest lull and shrink/dim to reflect remaining biomass (SPI-1388)

**Milestone 4 - Mothers & Spawning**
- Mother unit: a large, slow, high-HP command unit that cannot harvest, cannot auto-attack, and is never auto-targeted by enemies, but is selectable and movable (SPI-1421)
- Mother spawning: a Mother converts stored biomass into a new Level 1 Drone via `spawn_unit()`, placed clear of its body on a deterministic ring and announced on the EventBus (SPI-1422)

### Fixed
- Camera movement fix (SPI-1380)

### Development
- CI pipeline running GUT tests with code coverage and build (SPI-1367)
- Context-engineering infrastructure: skills, subagents, and workflows (SPI-1354–SPI-1361)
- Claude Code delegation config (hooks, permissions, run-tests skill), plus routine dependabot dependency bumps

---

*For full release history, see [GitHub Releases](https://github.com/johnburbridge/swarm-dominion/releases).*
