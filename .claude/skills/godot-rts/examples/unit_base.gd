class_name UnitBase extends CharacterBody2D
## Base class for all units in Swarm Dominion.
## Extend this class for specific unit types (Drone, Mother, etc.)

# Signals
signal health_changed(current: int, maximum: int)
signal unit_died
signal selected_changed(is_selected: bool)

# Constants
const SELECTION_HIGHLIGHT_COLOR := Color(0, 1, 0, 0.5)

# Exported properties
@export_group("Stats")
@export var max_health: int = 100
@export var move_speed: float = 200.0
@export var attack_damage: int = 10
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 1.0
@export var vision_radius: float = 300.0
@export var armor: int = 0

@export_group("Team")
@export var team: int = 0

# Runtime state
var current_health: int
var is_selected: bool = false
var current_target: Node2D
var current_resource_node: ResourceNode
var damage_multiplier: float = 1.0

# Command queue for shift-click orders
var command_queue: Array[UnitCommand] = []

# Node references
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: ProgressBar = $HealthBar
@onready var selection_indicator: Sprite2D = $SelectionIndicator
@onready var attack_timer: Timer = $AttackTimer
@onready var state_machine: UnitStateMachine = $StateMachine


func _ready() -> void:
	current_health = max_health
	_update_health_bar()
	_setup_selection_indicator()

	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	add_to_group("units")
	add_to_group("selectable")
	if team == GameManager.player_team:
		add_to_group("player_units")
	else:
		add_to_group("enemy_units")


func _setup_selection_indicator() -> void:
	selection_indicator.visible = false
	selection_indicator.modulate = SELECTION_HIGHLIGHT_COLOR


# Health system
func take_damage(amount: int, attacker: Node2D = null) -> void:
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	_update_health_bar()

	if current_health <= 0:
		_die()


func heal(amount: int) -> void:
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_update_health_bar()


func _update_health_bar() -> void:
	health_bar.value = float(current_health) / max_health * 100


func _die() -> void:
	unit_died.emit()
	EventBus.unit_died.emit(self)
	state_machine.change_state(UnitStateMachine.State.DEAD)

	# Wait for death animation, then remove
	await animation_player.animation_finished
	queue_free()


# Selection system
func set_selected(selected: bool) -> void:
	is_selected = selected
	selection_indicator.visible = selected
	selected_changed.emit(selected)


# Movement
func move_to(target_position: Vector2) -> void:
	navigation_agent.target_position = target_position
	state_machine.change_state(UnitStateMachine.State.MOVING)


func stop_current_action() -> void:
	command_queue.clear()
	current_target = null
	current_resource_node = null
	state_machine.change_state(UnitStateMachine.State.IDLE)


func hold_position() -> void:
	command_queue.clear()
	navigation_agent.target_position = global_position
	state_machine.change_state(UnitStateMachine.State.IDLE)


# Combat
func attack_target(target: Node2D) -> void:
	current_target = target
	state_machine.change_state(UnitStateMachine.State.ATTACKING)


func is_in_attack_range(target: Node2D) -> bool:
	return global_position.distance_to(target.global_position) <= attack_range


func find_nearest_enemy() -> Unit:
	var nearest: Unit = null
	var nearest_dist := INF

	var enemy_group = "enemy_units" if team == GameManager.player_team else "player_units"

	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist and dist <= vision_radius:
			nearest_dist = dist
			nearest = enemy

	return nearest


func _on_attack_timer_timeout() -> void:
	if is_instance_valid(current_target) and is_in_attack_range(current_target):
		GameManager.combat_system.apply_damage(self, current_target)


# Resource gathering
func gather_from(resource: ResourceNode) -> void:
	current_resource_node = resource
	state_machine.change_state(UnitStateMachine.State.GATHERING)


# Command queue
func issue_command(command: UnitCommand, queue: bool = false) -> void:
	if not queue:
		command_queue.clear()
	command_queue.append(command)

	if command_queue.size() == 1:
		command.execute(self)


func _process_command_queue() -> void:
	if command_queue.is_empty():
		return

	# Remove completed command and execute next
	command_queue.pop_front()
	if not command_queue.is_empty():
		command_queue[0].execute(self)
