extends Node

class_name InteractionWithShell

signal shell_hitted

@export var is_shell_hittable: bool = true
@export var immune_to_shell: bool = false

func _ready() -> void:
	metadata_inject()

func metadata_inject() -> void:
	get_parent().set_meta("interaction_with_shell", self)

func on_shell_hit(hit_position: Vector2) -> void:
	if not is_shell_hittable:
		return
	if immune_to_shell:
		return
	emit_signal("shell_hitted", hit_position)
	