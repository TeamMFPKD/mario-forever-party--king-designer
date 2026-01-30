class_name ShapeCastQuery

static func shape_query(body: CharacterBody2D, cast: ShapeCast2D) -> Array[Node2D]:
	var space_state = body.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = cast.shape
	query.collision_mask = cast.collision_mask
	query.collide_with_areas = cast.collide_with_areas
	query.collide_with_bodies = cast.collide_with_bodies
	query.transform = cast.global_transform
	
	var results = space_state.intersect_shape(query, cast.max_results)
	
	var nodes : Array[Node2D] = []
	for result in results:
		var collider = result.get("collider")
		if collider == null:
			continue
		nodes.append(collider as Node2D)
	return nodes
	
