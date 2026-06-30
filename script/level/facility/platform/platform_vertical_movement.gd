extends BasicMovement

@export var teleport_offset: float = 32.0

var level_camera: Camera2D
var limit_top
var limit_bottom
var origin_collision_layer

func _ready() -> void:
	super._ready()
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
	limit_top = level_camera.limit_top
	limit_bottom = level_camera.limit_bottom
	origin_collision_layer = move_object.collision_layer

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	var fc = func():
		move_object.collision_layer = origin_collision_layer
	if (speed_y < 0.0 and move_object.position.y < limit_top - teleport_offset + 6.0) \
	or (speed_y > 0.0 and move_object.position.y > limit_bottom + teleport_offset - 6.0):
		move_object.collision_layer = 0

	if speed_y < 0.0 and move_object.position.y < limit_top - teleport_offset:
		move_object.position.y = limit_bottom + teleport_offset
		move_object.reset_physics_interpolation()
		fc.call_deferred()
	elif speed_y > 0.0 and move_object.position.y > limit_bottom + teleport_offset:
		move_object.position.y = limit_top - teleport_offset
		move_object.reset_physics_interpolation()
		fc.call_deferred()
	
