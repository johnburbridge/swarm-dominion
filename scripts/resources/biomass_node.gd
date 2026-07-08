class_name BiomassNode extends StaticBody2D
## A harvestable biomass resource node.
## Units can gather biomass from this node to accumulate resources.

signal biomass_changed(current: int, maximum: int)
signal biomass_depleted
signal fully_regenerated

const MAX_DRAW_RADIUS: float = 20.0
const MIN_DRAW_RADIUS: float = 6.0
const MIN_DRAW_ALPHA: float = 0.4

@export var max_biomass: int = 100
@export var regen_rate: float = 2.0
@export var regen_delay: float = 10.0
@export var harvest_radius: float = 40.0

var current_biomass: int = 0
var _time_since_harvest: float = 0.0
var _regen_progress: float = 0.0


func _ready() -> void:
	current_biomass = max_biomass
	collision_layer = 4
	collision_mask = 0
	_setup_harvest_area()
	set_physics_process(false)


func _draw() -> void:
	var ratio: float = 0.0
	if max_biomass > 0:
		ratio = clampf(float(current_biomass) / float(max_biomass), 0.0, 1.0)
	var radius := display_radius_for_ratio(ratio)
	var dim := lerpf(MIN_DRAW_ALPHA, 1.0, ratio)
	draw_circle(Vector2.ZERO, radius, Color(0.4, 0.9, 0.3, 0.8 * dim))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(0.3, 1.0, 0.2, 0.6 * dim))


func display_radius_for_ratio(ratio: float) -> float:
	return lerpf(MIN_DRAW_RADIUS, MAX_DRAW_RADIUS, clampf(ratio, 0.0, 1.0))


func is_depleted() -> bool:
	return current_biomass <= 0


func harvest(amount: int) -> int:
	var extracted: int = min(amount, current_biomass)
	if extracted <= 0:
		return 0
	current_biomass -= extracted
	_time_since_harvest = 0.0
	_regen_progress = 0.0
	set_physics_process(true)
	biomass_changed.emit(current_biomass, max_biomass)
	queue_redraw()
	if current_biomass <= 0:
		biomass_depleted.emit()
	return extracted


func _physics_process(delta: float) -> void:
	if current_biomass >= max_biomass:
		return
	_time_since_harvest += delta
	if _time_since_harvest < regen_delay:
		return
	_regen_progress += regen_rate * delta
	var whole := int(_regen_progress)
	if whole <= 0:
		return
	_regen_progress -= float(whole)
	var before := current_biomass
	current_biomass = min(current_biomass + whole, max_biomass)
	if current_biomass == before:
		return
	biomass_changed.emit(current_biomass, max_biomass)
	queue_redraw()
	if current_biomass >= max_biomass:
		_regen_progress = 0.0
		fully_regenerated.emit()
		set_physics_process(false)


func _setup_harvest_area() -> void:
	var area := Area2D.new()
	area.name = "HarvestArea"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = harvest_radius
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
