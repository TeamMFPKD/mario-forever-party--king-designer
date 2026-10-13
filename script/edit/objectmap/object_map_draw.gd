extends Node2D

class_name ObjectMapDraw

@export var object_map_layer: ObjectMapLayer

func _ready() -> void:
	# 设置输入处理器
	setup_input_handler

func setup_input_handler() -> void:
	# 检查是否已有输入处理器 - 使用正确的相对路径
	var input_handler: Node = get_node("../../InputHandler")
	if not input_handler:
		# 如果没有，创建并添加
		var input_handler_script: GDScript = preload("uid://devgf5ccfvhwv")
		input_handler = input_handler_script.new()
		# 使用 call_deferred 避免父节点忙碌时添加子节点
		get_parent().call_deferred("add_child", input_handler)

# 选择对象
func select_object(object_name: String) -> void:
	if object_map_layer:
		object_map_layer.start_placing_object(object_name)

# 停止绘制
func stop_drawing() -> void:
	if object_map_layer:
		object_map_layer.stop_placing_object()
