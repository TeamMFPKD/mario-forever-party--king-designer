extends Node2D

class_name BackgroundSet

@export var gradient: Sprite2D
@export var background_bottom: Node2D
@export var cloud_top: Node2D

var room_left = 0;
var room_top = 0;
var room_right = 640;
var room_bottom = 480;

var level_camera : LevelCamera

func _ready() -> void:
	# Get level size
	level_camera = get_tree().get_first_node_in_group("level_camera") as LevelCamera
	level_camera.limit_changed.connect(_on_level_camera_limit_changed)

	background_set()
	
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
