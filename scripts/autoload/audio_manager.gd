extends Node
## Manages audio playback for music and sound effects.

@export var music_bus: String = "Music"
@export var sfx_bus: String = "SFX"

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8

func _ready() -> void:
	_setup_music_player()
	_setup_sfx_pool()


func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus
	add_child(_music_player)


func _setup_sfx_pool() -> void:
	for i in range(_sfx_pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = sfx_bus
		add_child(player)
		_sfx_players.append(player)


func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	_music_player.stream = stream
	_music_player.play()
	# TODO: Implement fade in


func stop_music(fade_out: float = 0.5) -> void:
	# TODO: Implement fade out
	_music_player.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return
	# All players busy, use first one
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = volume_db
	_sfx_players[0].play()


func play_sfx_at_position(stream: AudioStream, position: Vector2, volume_db: float = 0.0) -> void:
	# TODO: Implement positional audio with AudioStreamPlayer2D pool
	play_sfx(stream, volume_db)
