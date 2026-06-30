extends Node

signal beetroot_bounce
signal player_sound_bump

@export var beetroot: CharacterBody2D
@export var cast: ShapeCast2D
@export var path_to_movement: NodePath = "../BeetrootMovement"

var movement: BasicMovement

var interacting_blocks: Array[Node]

func _ready():
	movement = get_node(path_to_movement)

func _physics_process(_delta: float):
	var original_position = cast.position
	cast.position += Vector2(sign(movement.speed_x), sign(movement.speed_y))
	var results = ShapeCastQuery.shape_query(beetroot, cast)
	cast.position = original_position

	detect_enemies(results)
	
	detect_blocks(results)

func detect_enemies(results):
	for result in results:
		if !result.has_meta("interaction_with_beetroot"):
			continue
		var interaction_with_beetroot_node = result.get_meta("interaction_with_beetroot") as InteractionWithBeetroot
		if !interaction_with_beetroot_node.is_hittable:
			continue
		interaction_with_beetroot_node.on_beetroot_hit(beetroot.position)
		if interaction_with_beetroot_node.immune_to_beetroot:
			emit_signal("player_sound_bump")
		if interaction_with_beetroot_node.beetroot_bounce:
			emit_signal("beetroot_bounce")

func detect_blocks(results):
	for result in results:
		if !result.has_meta("interaction_with_block"):
			continue
		var block_hit_node = result.get_meta("interaction_with_block") as BlockHit
		block_hit_node.on_block_hit(beetroot)
		if not result in interacting_blocks:
			interacting_blocks.append(result)
			emit_signal("beetroot_bounce")
		
