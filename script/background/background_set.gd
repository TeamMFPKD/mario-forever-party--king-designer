extends Node2D

class_name BackgroundSet

@export var gradient: Sprite2D
@export var background_bottom: Node2D
@export var cloud_top: Node2D

var room_left = 0;
var room_top = 0;
var room_right = 640;
var room_bottom = 480;

var level_camera: LevelCamera
var _original_position: Vector2

func _ready() -> void:
	_original_position = position
	# Get level size
	level_camera = get_tree().get_first_node_in_group("level_camera") as LevelCamera
	level_camera.limit_changed.connect(_on_level_camera_limit_changed)

	room_left = level_camera.limit_left
	room_top = level_camera.limit_top
	room_right = level_camera.limit_right
	room_bottom = level_camera.limit_bottom
		
	background_set()


func _physics_process(_delta: float) -> void:
	if level_camera and level_camera.offset != Vector2.ZERO:
		position = _original_position + level_camera.offset
	else:
		position = _original_position
	
func _on_level_camera_limit_changed(top: int, left: int, right: int, bottom: int) -> void:
	room_left = left
	room_top = top
	room_right = right
	room_bottom = bottom

	background_set()

func background_set() -> void:
	# 渐变色背景
	if (gradient != null):
		var gradient_texture_2d = gradient.texture as GradientTexture2D
		gradient_texture_2d.height = int(room_bottom - room_top)
		gradient.position.y = (floor)((room_bottom + room_top) / 2.0)

	# 底部背景
	if (background_bottom != null):
		background_bottom.position.y = room_bottom

	# 顶部背景
	if (cloud_top != null):
		cloud_top.position.y = room_top
