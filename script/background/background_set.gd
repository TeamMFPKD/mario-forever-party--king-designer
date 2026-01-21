extends Node2D

class_name BackgroundSet

@export var gradient: Sprite2D
@export var background_bottom: Node2D
@export var cloud_top: Node2D

var room_width = 640;
var room_height = 480;

func _ready() -> void:
	# Get level size


	# 渐变色背景
	if (gradient != null):
		var gradient_texture_2d = gradient.texture as GradientTexture2D
		gradient_texture_2d.height = int(room_height)
		gradient.position.y = room_height / 2

	# 底部背景
	if (background_bottom != null):
		background_bottom.position.y = room_height
		