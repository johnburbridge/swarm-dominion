extends Node
## Manages overall game state and flow.

enum GameState { MENU, LOADING, PLAYING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MENU
var current_map: Node = null

# Player data
var players: Dictionary = {}  # player_id -> PlayerData


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_game(_map_path: String) -> void:
	current_state = GameState.LOADING
	# TODO: Load map, initialize players
	current_state = GameState.PLAYING
	EventBus.game_started.emit()


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		EventBus.game_paused.emit()


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		EventBus.game_resumed.emit()


func end_game(winning_team: int) -> void:
	current_state = GameState.GAME_OVER
	EventBus.game_ended.emit(winning_team)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()
