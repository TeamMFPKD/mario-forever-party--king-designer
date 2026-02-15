extends Node

signal bump_block

@export var basic_movement : BasicMovement
@export var thwomp : CharacterBody2D
@export var cast : ShapeCast2D

var hit : bool

func _physics_process(_delta: float) -> void:
	var origin_cast_pos_y = cast.position.y
	cast.position.y += 1.0
	var results = ShapeCastQuery.shape_query(thwomp, cast)
	cast.position.y = origin_cast_pos_y

	#print("thwomp interaction results: ", results)
	if results.size() < 2:
		hit = false
		return
	if hit:
		return
	for result in results:
		if not result.has_meta("interaction_with_block"):
			continue
		var block_hit_node = result.get_meta("interaction_with_block")
		# 不触发隐藏砖
		if block_hit_node.hidden:
			continue
		if block_hit_node.has_meta("is_brick"):
			block_hit_node.on_block_hit(thwomp)
			emit_signal("bump_block")
		else:
			block_hit_node.set_meta("sprout_down", true)
			block_hit_node.on_block_hit(thwomp)
			emit_signal("bump_block")
		hit = true
