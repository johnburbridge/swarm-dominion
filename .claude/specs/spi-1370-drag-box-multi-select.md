# Drag-Box Multi-Select (SPI-1370)

## Overview

Add click-and-drag rectangle selection so the player can select multiple friendly units at once. Extends the existing SelectionManager and input handling in main.gd.

## Core Mechanic

- Player holds left-click and drags to draw a selection rectangle on screen
- On release, all friendly units (team_id == 1) inside the rectangle get selected
- Drag activates after mouse moves 4px from click origin (prevents accidental drags)
- If the box captures zero friendly units, selection is cleared
- Single-click selection continues to work unchanged

## Visual

- White outline with translucent white fill
- Drawn via `_draw()` on a `Control` child node in screen space
- No new scene files or assets needed

## Architecture

### SelectionManager

Add `select_units(units: Array[UnitBase])` for batch selection without calling `deselect_all()` between each unit. Existing `select_unit()` unchanged.

### main.gd Input Flow

1. Left-click press: record start position, `_is_dragging = false`
2. Mouse motion while held: if distance > 4px threshold, set `_is_dragging = true`, trigger redraw
3. Left-click release: if dragging, query units in rect via `get_tree().get_nodes_in_group("units")` and screen-position containment check, call `select_units()`. If not dragging, fall through to existing single-click logic.

### Unit Querying

Use `get_tree().get_nodes_in_group("units")` and check if each unit's screen position falls inside the drag rect. Simpler and more reliable than physics shape queries for a 2D rectangle.

## Files Changed

| File | Change |
|------|--------|
| `scripts/autoload/selection_manager.gd` | Add `select_units()` method |
| `scripts/main.gd` | Drag tracking state, box drawing Control node, rectangle query |
| `tests/unit/test_selection_manager.gd` | Tests for `select_units()` |
| `tests/unit/test_drag_select.gd` | Tests for drag threshold, containment, team filtering |
