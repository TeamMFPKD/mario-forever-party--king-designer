class_name ShapeCastQuery

static func shape_query(body: Node2D, cast: ShapeCast2D) -> Array[Node2D]:
	if cast == null:
		push_error("ShapeCastQuery: cast parameter is null")
		return []
	if cast.shape == null:
		push_error("ShapeCastQuery: cast.shape is null")
		return []
	
	var space_state: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = cast.shape
	query.collision_mask = cast.collision_mask
	query.collide_with_areas = cast.collide_with_areas
	query.collide_with_bodies = cast.collide_with_bodies
	query.transform = cast.global_transform
	
	var results: Array[Dictionary] = space_state.intersect_shape(query, cast.max_results)
	
	var nodes: Array[Node2D] = []
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider")
		if collider == null:
			continue
		nodes.append(collider)
	return nodes
