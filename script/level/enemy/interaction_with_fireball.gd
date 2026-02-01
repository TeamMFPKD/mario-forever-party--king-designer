extends Node

class_name InteractionWithFireball

signal fireball_hitted

@export var is_hittable : bool = true
@export var immune_to_fireball : bool = false
@export var fireball_explode : bool = true

func _ready() -> void:
	metadata_inject()

func metadata_inject() -> void:
	get_parent().set_meta("interaction_with_fireball", self)

func on_fireball_hit() -> void:
	if not is_hittable:
		return
	if immune_to_fireball:
		return
	emit_signal("fireball_hitted")
