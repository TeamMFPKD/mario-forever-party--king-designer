extends Button

enum LevelSizeExpandMode {
	IN,
	OUT
}
enum LevelSizeExpandDirection {
	LEFT,
	RIGHT,
	TOP,
	BOTTOM
}

@export var expand_mode: LevelSizeExpandMode = LevelSizeExpandMode.IN
@export var expand_direction: LevelSizeExpandDirection = LevelSizeExpandDirection.LEFT

var level_camera: LevelCamera
var expand_distance: int = 32

## 一次“按住 → 松开”合并成一条撤销记录，避免每物理帧各写一条历史。
var _command_stack: CommandStack = null
var _resize_active: bool = false
var _limits_before: Vector4i = Vector4i.ZERO
var _position_before: Vector2 = Vector2.ZERO

func _ready() -> void:
	#pressed.connect(_on_button_pressed)
	level_camera = get_tree().get_first_node_in_group("level_camera") as LevelCamera
	_command_stack = CommandStack.find_in(get_tree())

func _physics_process(_delta: float) -> void:
	if not button_pressed:
		_finish_resize_session()
		return

	if level_camera == null or not is_instance_valid(level_camera):
		return

	if not _resize_active:
		_begin_resize_session()
	_apply_expand_step()

func _apply_expand_step() -> void:
	if expand_mode == LevelSizeExpandMode.OUT:
		if expand_direction == LevelSizeExpandDirection.LEFT:
			level_camera.set_limit_left(level_camera.limit_left - expand_distance)
			level_camera.position.x = level_camera.limit_left + 240
		elif expand_direction == LevelSizeExpandDirection.RIGHT:
			level_camera.set_limit_right(level_camera.limit_right + expand_distance)
			level_camera.position.x = level_camera.limit_right - 240
		elif expand_direction == LevelSizeExpandDirection.TOP:
			level_camera.set_limit_top(level_camera.limit_top - expand_distance)
			level_camera.position.y = level_camera.limit_top + 240
		elif expand_direction == LevelSizeExpandDirection.BOTTOM:
			level_camera.set_limit_bottom(level_camera.limit_bottom + expand_distance)
			level_camera.position.y = level_camera.limit_bottom - 240

	else:
		if expand_direction == LevelSizeExpandDirection.LEFT:
			level_camera.set_limit_left(level_camera.limit_left + expand_distance)
			level_camera.position.x = level_camera.limit_left + 240
		elif expand_direction == LevelSizeExpandDirection.RIGHT:
			level_camera.set_limit_right(level_camera.limit_right - expand_distance)
			level_camera.position.x = level_camera.limit_right - 240
		elif expand_direction == LevelSizeExpandDirection.TOP:
			level_camera.set_limit_top(level_camera.limit_top + expand_distance)
			level_camera.position.y = level_camera.limit_top - 240
		elif expand_direction == LevelSizeExpandDirection.BOTTOM:
			level_camera.set_limit_bottom(level_camera.limit_bottom - expand_distance)
			level_camera.position.y = level_camera.limit_bottom - 240

func _begin_resize_session() -> void:
	_resize_active = true
	_limits_before = _current_limits()
	_position_before = level_camera.position

func _finish_resize_session() -> void:
	if not _resize_active:
		return
	_resize_active = false
	if level_camera == null or not is_instance_valid(level_camera):
		return

	var limits_after: Vector4i = _current_limits()
	var position_after: Vector2 = level_camera.position

	if _command_stack == null:
		_command_stack = CommandStack.find_in(get_tree())
	if _command_stack == null:
		return
	# 尺寸在按住期间已经实时应用，这里只补一条历史记录。
	var command: CmdResizeLevel = CmdResizeLevel.create(
		level_camera, _limits_before, limits_after, _position_before, position_after)
	if command != null:
		_command_stack.push_executed_command(command)

func _current_limits() -> Vector4i:
	return Vector4i(
		level_camera.limit_top,
		level_camera.limit_left,
		level_camera.limit_right,
		level_camera.limit_bottom,
	)
