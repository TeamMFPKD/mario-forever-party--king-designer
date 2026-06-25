extends BasicMovement

func _ready():
	super()
	gravity = 0.0
	overlap_turn = false
	edge_detect = false
	is_clear_pipe_allowed = false
	initially_face_to_player = false

	var p = get_tree().get_first_node_in_group("player") as Node2D
	if p:
		var dir = (p.global_position - move_object.global_position).normalized()
		var base_speed = speed_x
		speed_x = dir.x * base_speed
		speed_y = dir.y * base_speed
	else:
		move_object.queue_free()
		return


func _physics_process(delta):
	apply_speed()
	move()
	if ani:
		ani.rotation += 12 * delta
