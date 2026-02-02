extends BasicMovement

@export var teleport_offset: float = 32.0

var level_camera : Camera2D
var limit_top
var limit_bottom

func _ready() -> void:
	super._ready()
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
	limit_top = level_camera.limit_top
	limit_bottom = level_camera.limit_bottom

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if speed_y < 0.0 and move_object.position.y < limit_top - teleport_offset:
		move_object.position.y = limit_bottom + teleport_offset
		move_object.reset_physics_interpolation()
	elif speed_y > 0.0 and move_object.position.y > limit_bottom + teleport_offset:
		move_object.position.y = limit_top - teleport_offset
		move_object.reset_physics_interpolation()
	