extends Node

signal shell_harded

@export var path_to_shell : NodePath = ".."
@export var path_to_cast : NodePath = "../BasicShapeCast2D"
@export var path_to_shell_status : NodePath = "../ShellStatus"
@export var path_to_movement : NodePath = "../BasicMovement"

var shell : CharacterBody2D
var cast : ShapeCast2D
var movement : BasicMovement
var shell_status : ShellStatus
var is_moving : bool = false

func _ready() -> void:
	shell = get_node(path_to_shell) as CharacterBody2D
	cast = get_node(path_to_cast) as ShapeCast2D
	shell_status = get_node(path_to_shell_status) as ShellStatus
	movement = get_node(path_to_movement) as BasicMovement

func _physics_process(delta):
	is_moving = moving_check()

	if not is_moving:
		return

	var original_position = cast.position
	cast.position += Vector2(sign(movement.speed_x), sign(movement.speed_y))
	var results = ShapeCastQuery.shape_query(shell, cast)
	cast.position = original_position

	detect_enemy(results)

	detect_block(results)	

func detect_enemy(results):
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

func detect_block(results):
	var turned : bool = false
	for result in results:
		if !result.has_meta("interaction_with_block"):
			continue
		var block_hit_node = result.get_meta("interaction_with_block") as BlockHit
		block_hit_node.on_block_hit(shell)
		if not turned and not shell.is_on_wall():
			turned = true
			movement.speed_x *= -1

func moving_check() -> bool:
	return shell_status.is_moving
