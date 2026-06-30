extends Area2D

var timer: int = 0

func _physics_process(_delta: float) -> void:
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if not body.has_meta("interaction_with_bump"):
			continue
		var interaction_with_bump_node = body.get_meta("interaction_with_bump") as InteractionWithBump
		if not interaction_with_bump_node.is_bumpable:
			continue
		interaction_with_bump_node.on_bump_hit(position)

	timer += 1
	if timer > 6:
		queue_free()
