extends Node

class_name InteractionWithBump

signal bumped

@export var is_bumpable : bool = true
@export var immune_to_bump : bool = false

func _ready() -> void:
	metadata_inject()

func metadata_inject() -> void:
	get_parent().set_meta("interaction_with_bump", self)

func on_bump_hit() -> void:
	if not is_bumpable:
		return
	if immune_to_bump:
		return
	emit_signal("bumped")
	