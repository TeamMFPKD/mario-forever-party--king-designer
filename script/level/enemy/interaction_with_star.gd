extends Node

class_name InteractionWithStar

signal star_hitted

@export var is_hittable : bool = true
@export var immune_to_star : bool = false
@export var star_explode : bool = true

func _ready() -> void:
	metadata_inject()

func metadata_inject() -> void:
	get_parent().set_meta("interaction_with_star", self)

func on_star_hit() -> void:
	if not is_hittable:
		return
	if immune_to_star:
		return
	emit_signal("star_hitted")
