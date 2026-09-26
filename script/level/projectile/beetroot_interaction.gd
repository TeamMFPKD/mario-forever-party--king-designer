extends Node

signal beetroot_bounce
signal player_sound_bump

@export var beetroot: CharacterBody2D
@export var cast: ShapeCast2D
@export var path_to_movement: NodePath = "../BeetrootMovement"

var movement: BasicMovement

var interacting_blocks: Array[Node]

func _ready() -> void:
	movement = get_node(path_to_movement)

func _physics_process(_delta: float) -> void:
	var original_position: Vector2 = cast.position
	cast.position += Vector2(signf(movement.speed_x), signf(movement.speed_y))
	var results: Array[Node2D] = ShapeCastQuery.shape_query(beetroot, cast)
	cast.position = original_position

	detect_enemies(results)
	
	detect_blocks(results)

func detect_enemies(results: Array[Node2D]) -> void:
	for result: Node2D in results:
		if !result.has_meta("interaction_with_beetroot"):
			continue
		var interaction_with_beetroot_node: InteractionWithBeetroot = result.get_meta("interaction_with_beetroot")
		if !interaction_with_beetroot_node.is_hittable:
			continue
		interaction_with_beetroot_node.on_beetroot_hit(beetroot.position)
		if interaction_with_beetroot_node.immune_to_beetroot:
			emit_signal("player_sound_bump")
		if interaction_with_beetroot_node.beetroot_bounce:
			emit_signal("beetroot_bounce")

func detect_blocks(results: Array[Node2D]) -> void:
	for result: Node2D in results:
		if !result.has_meta("interaction_with_block"):
			continue
		var block_hit_node: BlockHit = result.get_meta("interaction_with_block")
		block_hit_node.on_block_hit(beetroot)
		if not result in interacting_blocks:
			interacting_blocks.append(result)
			emit_signal("beetroot_bounce")
		
