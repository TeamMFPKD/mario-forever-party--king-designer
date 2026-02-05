extends Node

signal shell_harded

@export var path_to_shell : NodePath = ".."
@export var path_to_cast : NodePath = "../BasicShapeCast2D"
@export var path_to_shell_status : NodePath = "../ShellStatus"

var shell : CharacterBody2D
var cast : ShapeCast2D
var shell_status : ShellStatus
var is_moving : bool = false

func _ready() -> void:
	shell = get_node(path_to_shell) as CharacterBody2D
	cast = get_node(path_to_cast) as ShapeCast2D
	shell_status = get_node(path_to_shell_status) as ShellStatus

func _physics_process(delta):
	is_moving = moving_check()

	if not is_moving:
		return

	var results = ShapeCastQuery.shape_query(shell, cast)
	for result in results:
		# 排除自身
		if result == shell:
			continue
		if result.has_meta("interaction_with_shell"):
			var interaction_with_shell = result.get_meta("interaction_with_shell") as InteractionWithShell
			if not interaction_with_shell.is_shell_hittable:
				continue
			interaction_with_shell.on_shell_hit(shell.position)
			if interaction_with_shell.immune_to_shell \
			# 撞到其他 shell
			or (result.is_in_group("shell") and result.get_node("ShellStatus").is_moving):
				emit_signal("shell_harded")

func moving_check() -> bool:
	return shell_status.is_moving
