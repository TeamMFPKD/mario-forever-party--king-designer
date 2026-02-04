extends Node

class_name InteractionWithBeetroot

signal beetroot_hitted(hit_position: Vector2)

@export var is_hittable : bool = true
@export var immune_to_beetroot : bool = false
@export var beetroot_bounce : bool = true

func _ready() -> void:
	metadata_inject()

func metadata_inject() -> void:
	get_parent().set_meta("interaction_with_beetroot", self)
	
func on_beetroot_hit(hit_position: Vector2) -> void:
	if not is_hittable:
		return
	if immune_to_beetroot:
		return
	emit_signal("beetroot_hitted", hit_position)
