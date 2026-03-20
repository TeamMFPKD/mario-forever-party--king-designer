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

@export var expand_mode = LevelSizeExpandMode.IN
@export var expand_direction = LevelSizeExpandDirection.LEFT

var level_camera: LevelCamera
var expand_distance = 32

func _ready() -> void:
	#pressed.connect(_on_button_pressed)
	level_camera = get_tree().get_first_node_in_group("level_camera") as LevelCamera

func _physics_process(_delta: float) -> void:
	if not button_pressed:
		return

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