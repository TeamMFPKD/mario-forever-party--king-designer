class_name CmdResizeLevel
extends Command

## 关卡尺寸命令。
##
## 长按尺寸按钮时 LevelCamera 的边界按物理帧连续改动（所见即所得），
## 所以整个“按住 → 松开”过程在松手时压成一条历史记录，与 CmdMoveObject
## 一样走 push_executed_command()，execute() 只在重做时被调用。
##
## 边界用 Vector4i(top, left, right, bottom) 承载，顺序与
## LevelManager.level_size 一致。相机位置一起保存：缩到最小视野时相机被
## 夹到关卡中心，撤销后若只还原边界，视野会停在新边界之外。

var _level_camera: LevelCamera = null
var _before_limits: Vector4i = Vector4i.ZERO
var _after_limits: Vector4i = Vector4i.ZERO
var _before_position: Vector2 = Vector2.ZERO
var _after_position: Vector2 = Vector2.ZERO

static func create(
		level_camera: LevelCamera,
		before_limits: Vector4i,
		after_limits: Vector4i,
		before_position: Vector2,
		after_position: Vector2
) -> CmdResizeLevel:
	if level_camera == null or not is_instance_valid(level_camera):
		return null
	if before_limits == after_limits and before_position == after_position:
		return null
	var command: CmdResizeLevel = CmdResizeLevel.new()
	command._level_camera = level_camera
	command._before_limits = before_limits
	command._after_limits = after_limits
	command._before_position = before_position
	command._after_position = after_position
	return command

func get_display_name() -> String:
	return "ResizeLevel"

func execute() -> void:
	_apply(_after_limits, _after_position)

func undo() -> void:
	_apply(_before_limits, _before_position)

func is_valid() -> bool:
	return _level_camera != null and is_instance_valid(_level_camera)

func _apply(limits: Vector4i, camera_position: Vector2) -> void:
	if not is_valid():
		return
	_level_camera.apply_limits(limits.x, limits.y, limits.z, limits.w)
	_level_camera.position = camera_position
