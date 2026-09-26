extends Node

signal shell_harded

@export var path_to_shell: NodePath = ".."
@export var path_to_cast: NodePath = "../BasicShapeCast2D"
@export var path_to_shell_status: NodePath = "../ShellStatus"
@export var path_to_movement: NodePath = "../BasicMovement"

var shell: CharacterBody2D
var cast: ShapeCast2D
var movement: BasicMovement
var shell_status: ShellStatus
var is_moving: bool = false

func _ready() -> void:
	shell = get_node(path_to_shell) as CharacterBody2D
	cast = get_node(path_to_cast) as ShapeCast2D
	shell_status = get_node(path_to_shell_status) as ShellStatus
	movement = get_node(path_to_movement) as BasicMovement

func _physics_process(_delta: float) -> void:
	is_moving = moving_check()

	if not is_moving:
		return

	var original_position: Vector2 = cast.position
	cast.position += Vector2(signf(movement.speed_x), 0.0)
	var results: Array[Node2D] = ShapeCastQuery.shape_query(shell, cast)
	cast.position = original_position

	detect_enemy(results)

	detect_block(results)	

func detect_enemy(results: Array[Node2D]) -> void:
	for result: Node2D in results:
		# 排除自身
		if result == shell:
			continue
		if result.has_meta("interaction_with_shell"):
			var interaction_with_shell: InteractionWithShell = result.get_meta("interaction_with_shell")
			if not interaction_with_shell.is_shell_hittable:
				continue
			interaction_with_shell.on_shell_hit(shell.position)
			var other_moving_shell: bool = false
			if result.is_in_group("shell"):
				var other_shell_status: ShellStatus = result.get_node("ShellStatus")
				other_moving_shell = other_shell_status.is_moving
			if interaction_with_shell.immune_to_shell \
			# 撞到其他 shell
			or other_moving_shell:
				emit_signal("shell_harded")

func detect_block(results: Array[Node2D]) -> void:
	var turned: bool = false
	for result: Node2D in results:
		if !result.has_meta("interaction_with_block"):
			continue
		var block_hit_node: BlockHit = result.get_meta("interaction_with_block")
		if block_hit_node.hidden:
			continue
		block_hit_node.on_block_hit(shell)
		if not turned and not shell.is_on_wall():
			turned = true
			movement.speed_x *= -1

func moving_check() -> bool:
	return shell_status.is_moving