extends Node

signal beetroot_bounce

@export var beetroot : CharacterBody2D
@export var cast : ShapeCast2D

func _physics_process(delta):
	var results = ShapeCastQuery.shape_query(beetroot, cast)
	for result in results:
		if !result.has_meta("interaction_with_beetroot"):
			continue
		var interaction_with_beetroot_node = result.get_meta("interaction_with_beetroot") as InteractionWithBeetroot
		if !interaction_with_beetroot_node.is_hittable:
			continue
		interaction_with_beetroot_node.on_beetroot_hit(beetroot.position)
		if interaction_with_beetroot_node.beetroot_bounce:
			emit_signal("beetroot_bounce")
