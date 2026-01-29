extends Node2D

class_name ObjectMapDraw

@export var object_map_layer: ObjectMapLayer

func _ready():
	# 设置输入处理器
	setup_input_handler

func setup_input_handler():
	# 检查是否已有输入处理器 - 使用正确的相对路径
	var input_handler = get_node("../../InputHandler")
	if not input_handler:
		# 如果没有，创建并添加
		var input_handler_script = preload("uid://devgf5ccfvhwv")
		input_handler = input_handler_script.new()
		# 使用 call_deferred 避免父节点忙碌时添加子节点
		get_parent().call_deferred("add_child", input_handler)

# 选择对象
func select_object(object_name: String):
	if object_map_layer:
		object_map_layer.start_placing_object(object_name)

# 停止绘制
func stop_drawing():
	if object_map_layer:
		object_map_layer.stop_placing_object()
