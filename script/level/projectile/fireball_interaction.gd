extends Node

signal fireball_explode

@export var fireball : CharacterBody2D
@export var cast : ShapeCast2D

func _physics_process(delta):
	var results = ShapeCastQuery.shape_query(fireball, cast)

	for result in results:
		if !result.has_meta("interaction_with_fireball"):
			continue
		var interaction_with_fireball_node = result.get_meta("interaction_with_fireball") as InteractionWithFireball
		if !interaction_with_fireball_node.is_hittable:
			continue
		interaction_with_fireball_node.on_fireball_hit(fireball.position)
		if interaction_with_fireball_node.fireball_explode:
			emit_signal("fireball_explode")
			fireball.queue_free()
