extends BasicMovement

@export var path_to_shell_status: NodePath = "../ShellStatus"
@export var bump_speed_x : float = -45.0

var shell_status: ShellStatus

var bumping : bool = false

func _ready() -> void:
	super._ready()
	shell_status = get_node(path_to_shell_status)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if move_object.is_on_floor() and bumping:
		bumping = false
		if not shell_status.is_moving:
			speed_x = 0.0

func set_jump_speed() -> void:
	pass

func _on_bumped(hit_position: Vector2) -> void:
	speed_y = jump_speed
	move_object.position.y -= 1.0
	shell_status.is_moving = false
	ani.flip_v = true
	bumping = true
	if move_object.position.x < hit_position.x:
		speed_x = -abs(bump_speed_x)
	else:
		speed_x = abs(bump_speed_x)
