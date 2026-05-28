extends Node

@export var normal: Texture2D
@export var hold: Texture2D

const OFFSET: Vector2 = Vector2(25, 25)

func _ready():
	# 设置默认光标
	if normal != null:
		set_cursor_normal()

# 封装方法用于设置普通光标
func set_cursor_normal():
	if normal != null:
		DisplayServer.cursor_set_custom_image(normal, DisplayServer.CURSOR_ARROW, OFFSET)

# 封装方法用于设置按下状态光标
func set_cursor_hold():
	if hold != null:
		DisplayServer.cursor_set_custom_image(hold, DisplayServer.CURSOR_ARROW, OFFSET)

# 通用方法用于设置任意光标
func set_cursor(texture: Texture2D, hotspot: Vector2 = OFFSET):
	if texture != null:
		DisplayServer.cursor_set_custom_image(texture, DisplayServer.CURSOR_ARROW, hotspot)

# 重置为系统默认光标
func reset_cursor():
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)