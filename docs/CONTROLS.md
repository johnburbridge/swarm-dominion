# Controls

Every keyboard and mouse binding the game responds to.

The `Action` column gives the input-map name from `project.godot`, for anyone
rebinding or reading the code. Bindings with no action name are handled as raw
keycodes in `scripts/main.gd`.

An in-game controls screen is planned for Milestone 15; until then this file is the
reference.

### What is guaranteed, and what is not

`tests/unit/test_controls_doc.gd` fails the build if this file drifts from the code,
but only along the axes it can see. It **does** enforce that every input-map action and
every raw keycode `main.gd` handles is documented here, with the right key, and that
nothing documented has been deleted from the code.

It cannot see, and this file may therefore be wrong about:

* **HUD buttons and panels** — those issue commands from `scripts/ui/`, not the input map
* **what a command does**, as opposed to what it is bound to — every "Effect" cell below
  is unverified prose
* input handled outside `scripts/main.gd` as raw events: mouse wheel, gestures, joypad,
  double-click, or `Shortcut` resources set on buttons in a `.tscn`
* anything a player rebinds at runtime, once Milestone 15 ships a settings screen

Treat the Input and Action columns as checked, and the Effect column as documentation.

## Selection

You can only select your own units.

| Input | Action | Effect |
|---|---|---|
| Left click a unit | `select` | Select that unit |
| Left click empty ground | `select` | Clear the selection |
| Left click + drag | `select` | Box-select every one of your units inside the box |

`select` must stay bound to a **mouse button** — the handlers test for a mouse-button
event before consulting the action, so rebinding it to a key silently does nothing.

## Unit commands

| Input | Action | Effect |
|---|---|---|
| Right click ground | `command` | Move the selection there |
| Right click an enemy | `command` | Attack it — the selection spreads around the target rather than stacking |
| Right click a biomass node | `command` | Harvest it. A depleted node falls through to a move order |
| <kbd>A</kbd>, then left click | `attack_move` | Attack-move to that point: travel there, engaging anything met on the way |

<kbd>A</kbd> **arms** the order; the *next left click* issues it. If both attack-move and
rally placement are armed, rally placement wins.

## Mother commands

A Mother shows a command panel at the bottom of the screen while selected.

| Input | Action | Effect |
|---|---|---|
| <kbd>R</kbd>, then left click | `set_rally` | Set the rally point — newly spawned Drones walk there |
| <kbd>Shift</kbd>+<kbd>R</kbd> | `clear_rally` | Clear the rally, reverting to the default |
| **Spawn Drone** button | — | Spawn a Drone. Greyed out when you cannot afford one |
| **Set Rally** button | — | Same as <kbd>R</kbd> |
| **Clear Rally** button | — | Same as <kbd>Shift</kbd>+<kbd>R</kbd>. Only appears when a rally is set |

<kbd>R</kbd> only arms if at least one of your Mothers is selected. Both rally
commands apply to *every* selected Mother you own.

With no explicit rally, spawned Drones gather just behind the Mother — trailing her
when she is moving, directly below her when she is still. That is what **Clear Rally**
returns you to.

## Control groups

| Input | Effect |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>1</kbd>–<kbd>5</kbd> | Assign the current selection to that group |
| <kbd>1</kbd>–<kbd>5</kbd> | Select that group |
| <kbd>1</kbd>–<kbd>5</kbd> twice quickly | Select it and centre the camera on it (within 0.3s) |

## Camera

| Input | Action | Effect |
|---|---|---|
| Left click the minimap | `select` | Jump the camera to that point |
| <kbd>1</kbd>–<kbd>5</kbd> twice quickly | — | Centre on that control group |

There is no keyboard panning or zoom yet — see below.

## Game

| Input | Action | Effect |
|---|---|---|
| <kbd>Esc</kbd> | `ui_cancel` | Pause, or resume if already paused |

`ui_cancel` is a Godot engine-default action rather than one this project declares, so
it is absent from the manifest at the bottom of this file. It still drives real
behaviour, which is why the drift guard also checks every action the code reads.

## Debug

Not player-facing; present in development builds.

| Input | Effect |
|---|---|
| <kbd>B</kbd> | Spawn a Drone, bypassing the HUD (temporary, SPI-1422) |

<kbd>B</kbd> uses the first Mother of yours found when the map loads, **not** whichever
one you have selected.

## Declared but not implemented

`camera_up` (<kbd>W</kbd>), `camera_down` (<kbd>S</kbd>), `camera_left` (<kbd>A</kbd>)
and `camera_right` (<kbd>D</kbd>) exist in the input map, but nothing reads them — the
camera does not respond to WASD.

Note that `camera_left` and `attack_move` are **both bound to <kbd>A</kbd>**. Whoever
implements keyboard panning has to resolve that collision first, or holding <kbd>A</kbd>
to pan will also arm an attack-move.

<!-- Raw keycodes main.gd handles directly, outside the input map. Compared two-way
     against a scan of main.gd, so deleting a KEY_* branch fails the build here rather
     than leaving this file promising a hotkey nothing handles. -->
<!-- raw-keys: 1, 5, B -->

<!-- Machine-readable manifest for tests/unit/test_controls_doc.gd, as name:key pairs.
     Keep in sync with the input map in project.godot — including the key, not just the
     action name; the drift guard fails the build otherwise. -->
<!-- input-actions: attack_move:A, camera_down:S, camera_left:A, camera_right:D, camera_up:W, clear_rally:Shift+R, command:MouseRight, select:MouseLeft, set_rally:R -->
