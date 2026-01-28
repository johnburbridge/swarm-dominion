extends Node
## Global event bus for cross-system communication.
## Connect to these signals to respond to game events.

# Unit events
signal unit_spawned(unit: Node)
signal unit_died(unit: Node)
signal unit_selected(unit: Node)
signal unit_deselected(unit: Node)

# Resource events
signal resources_changed(player_id: int, new_amount: int)
signal supply_changed(player_id: int, current: int, maximum: int)

# Control point events
signal control_point_captured(point: Node, team_id: int)
signal control_point_contested(point: Node)
signal victory_points_changed(player_id: int, points: int)

# Game state events
signal game_started()
signal game_paused()
signal game_resumed()
signal game_ended(winning_team: int)

# Match events
signal match_countdown_started(seconds: int)
signal match_timer_updated(seconds_remaining: int)
