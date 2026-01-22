extends Node

class_name InputHandler

# 输入状态信号
signal input_clicked(position: Vector2)
signal input_released(position: Vector2)
signal input_dragged(position: Vector2)

# 公共属性 - 其他脚本可以直接访问这些属性
var is_clicking: bool = false
var current_position: Vector2 = Vector2.ZERO
var last_click_position: Vector2 = Vector2.ZERO

func _ready():
	# 设置输入处理优先级，确保在其他脚本之前处理输入
	process_priority = -1

func _input(event):
	# 处理鼠标点击事件
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_click_event(event.pressed, event.position)
	
	# 处理鼠标移动事件
	elif event is InputEventMouseMotion:
		if is_clicking:
			handle_drag_event(event.position)
		else:
			current_position = event.position
	
	# 处理触摸屏点击事件
	elif event is InputEventScreenTouch:
		handle_click_event(event.pressed, event.position)
	
	# 处理触摸屏拖拽事件
	elif event is InputEventScreenDrag:
		if is_clicking:
			handle_drag_event(event.position)

func handle_click_event(pressed: bool, position: Vector2):
	is_clicking = pressed
	current_position = position
	
	if pressed:
		last_click_position = position
		input_clicked.emit(position)
	else:
		input_released.emit(position)

func handle_drag_event(position: Vector2):
	current_position = position
	input_dragged.emit(position)

# 公共方法 - 其他脚本可以调用的接口

## 检查是否正在点击
func is_input_active() -> bool:
	return is_clicking

## 获取当前输入位置
func get_input_position() -> Vector2:
	return current_position

## 获取最后一次点击的位置
func get_last_click_position() -> Vector2:
	return last_click_position

## 检查指定位置是否被点击（带容差范围）
func is_position_clicked(position: Vector2, tolerance: float = 10.0) -> bool:
	if not is_clicking:
		return false
	return position.distance_to(current_position) <= tolerance

## 将世界坐标转换为本地坐标（相对于指定节点）
func get_local_position(relative_to: Node2D) -> Vector2:
	return relative_to.to_local(current_position)

## 将世界坐标转换为指定TileMap的单元格坐标
func get_tilemap_cell_position(tilemap: TileMapLayer, relative_to: Node2D = null) -> Vector2i:
	var local_pos: Vector2
	if relative_to:
		local_pos = relative_to.to_local(current_position)
	else:
		local_pos = current_position
	
	if tilemap and tilemap.tile_set:
		var cell_size = tilemap.tile_set.tile_size
		return Vector2i(
			floor(local_pos.x / cell_size.x),
			floor(local_pos.y / cell_size.y)
		)
	return Vector2i.ZERO