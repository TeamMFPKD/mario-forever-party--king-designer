extends Node

signal shell_harded

@export var path_to_shell : NodePath = ".."
@export var path_to_cast : NodePath = "../BasicShapeCast2D"

var shell : CharacterBody2D
var cast : ShapeCast2D
var is_moving : bool = false

func _ready() -> void:
	shell = get_node(path_to_shell) as CharacterBody2D
	cast = get_node(path_to_cast) as ShapeCast2D

func _physics_process(delta):
	if not is_moving:
		return
	
	var results = ShapeCastQuery.shape_query(shell, cast)
	for result in results:
		# 排除自身
		if result == self:
			continue
		if result.has_meta("interaction_with_shell"):
			var interaction_with_shell = result.get_meta("interaction_with_shell") as InteractionWithShell
			if not interaction_with_shell.is_shell_hittable:
				continue
			interaction_with_shell.on_shell_hit(shell.position)
			if interaction_with_shell.immune_to_shell:
				emit_signal("shell_harded")
