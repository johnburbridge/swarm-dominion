class_name MotherUnit extends UnitBase
## The Mother: a large, slow, high-HP command unit. It cannot harvest and cannot
## auto-attack — both fall out of the "mother" stats entry having no
## harvest_speed / attack_range (they default to 0, so harvest_at() no-ops and
## no attack Area2D is built). It is also never auto-targeted by enemies. Later
## M4 stories add spawning (SPI-1422) and rally points (SPI-1424) here.


func _init() -> void:
	unit_type = "mother"


func is_auto_targetable() -> bool:
	return false
