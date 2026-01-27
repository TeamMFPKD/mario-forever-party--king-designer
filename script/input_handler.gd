extends Node

class_name InputHandler

# 输入状态信号
signal input_clicked(position: Vector2)
signal input_released(position: Vector2)
signal input_dragged(position: Vector2)
signal input_right_clicked(position: Vector2)  # 新增：右键点击信号

# 公共属性 - 其他脚本可以直接访问这些属性
var is_clicking: bool = false
var is_right_clicking: bool = false  # 新增：右键点击状态
var current_position: Vector2 = Vector2.ZERO
var last_click_position: Vector2 = Vector2.ZERO

# 用于跟踪上次操作的网格位置，避免重复操作同一位置
var last_operation_grid_pos: Vector2i = Vector2i(-1, -1)

func _ready():
	# 设置输入处理优先级，确保在其他脚本之前处理输入
	process_priority = -1
	# 开始处理输入
	set_process_input(true)
	# 启用_process函数
	set_process(true)

func _process(delta):
	# 获取当前鼠标屏幕位置并转换为世界坐标
	var mouse_position = get_viewport().get_mouse_position()
	var world_position = convert_screen_to_world(mouse_position)
	
	# 检查鼠标按键是否仍在按下状态，即使没有移动也持续执行操作
	if is_clicking:
		# 持续发送拖拽信号以保持绘制/删除操作
		perform_operation_at_position(world_position)
	
	if is_right_clicking:
		# 持续清除操作
		perform_erase_at_position(world_position)

func perform_operation_at_position(pos: Vector2):
	# 计算当前网格位置
	var viewport = get_viewport()
	if not viewport:
		return
	
	# 获取TileMapLayer节点以计算网格坐标
	var level_node = get_parent()
	if level_node:
		var tile_map_draw = level_node.get_node_or_null("TileMapLayer/TileMapDraw")
		if tile_map_draw and tile_map_draw.tile_map and tile_map_draw.tile_map.tile_set:
			var cell_size = tile_map_draw.tile_map.tile_set.tile_size
			var grid_pos = Vector2i(
				floor(pos.x / cell_size.x),
				floor(pos.y / cell_size.y)
			)
			
			# 只有在网格位置发生变化时才执行操作，避免重复操作同一网格
			if grid_pos != last_operation_grid_pos:
				last_operation_grid_pos = grid_pos
				input_dragged.emit(pos)

func perform_erase_at_position(pos: Vector2):
	# 计算当前网格位置
	var viewport = get_viewport()
	if not viewport:
		return
	
	# 获取TileMapLayer节点以计算网格坐标
	var level_node = get_parent()
	if level_node:
		var tile_map_draw = level_node.get_node_or_null("TileMapLayer/TileMapDraw")
		if tile_map_draw and tile_map_draw.tile_map and tile_map_draw.tile_map.tile_set:
			var cell_size = tile_map_draw.tile_map.tile_set.tile_size
			var grid_pos = Vector2i(
				floor(pos.x / cell_size.x),
				floor(pos.y / cell_size.y)
			)
			
			# 只有在网格位置发生变化时才执行操作，避免重复操作同一网格
			if grid_pos != last_operation_grid_pos:
				last_operation_grid_pos = grid_pos
				var level_control = get_tree().get_first_node_in_group("level_control") as LevelControl
				if level_control:
					level_control.erase_at_position_immediate(pos)

func _input(event):
	# 重置上次操作网格位置，因为鼠标可能移动到了新的位置
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_operation_grid_pos = Vector2i(-1, -1)

	# 处理鼠标点击事件
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var world_position = convert_screen_to_world(event.position)
			handle_click_event(event.pressed, world_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:  # 修改：处理右键按住
			var world_position = convert_screen_to_world(event.position)
			handle_right_click_event(event.pressed, world_position)
	
	# 处理鼠标移动事件
	elif event is InputEventMouseMotion:
		var world_position = convert_screen_to_world(event.position)
		if is_clicking:
			handle_drag_event(world_position)
		# 如果右键按住并移动，则持续清除
		elif is_right_clicking:
			handle_right_click_hold(world_position)
		else:
			current_position = world_position
	
	# 处理触摸屏点击事件
	elif event is InputEventScreenTouch:
		var world_position = convert_screen_to_world(event.position)
		handle_click_event(event.pressed, world_position)
	
	# 处理触摸屏拖拽事件
	elif event is InputEventScreenDrag:
		var world_position = convert_screen_to_world(event.position)
		if is_clicking:
			handle_drag_event(world_position)

func convert_screen_to_world(screen_position: Vector2) -> Vector2:
	# 获取视口
	var viewport = get_viewport()
	if viewport:
		# 使用视口的画Canvas变换将屏幕坐标转换为世界坐标
		var canvas_transform = viewport.get_canvas_transform()
		return canvas_transform.affine_inverse() * screen_position
	return screen_position

func handle_click_event(pressed: bool, position: Vector2):
	is_clicking = pressed
	current_position = position
	
	if pressed:
		last_click_position = position
		last_operation_grid_pos = Vector2i(-1, -1)  # 重置网格位置跟踪
		input_clicked.emit(position)
	else:
		input_released.emit(position)

func handle_right_click_event(pressed: bool, position: Vector2):
	is_right_clicking = pressed
	current_position = position
	
	if pressed:
		last_operation_grid_pos = Vector2i(-1, -1)  # 重置网格位置跟踪
		# 右键按下时立即清除一次
		input_right_clicked.emit(position)
		var level_control = get_tree().get_first_node_in_group("level_control") as LevelControl
		if level_control:
			level_control.erase_at_position_immediate(position)

func handle_right_click_hold(position: Vector2):
	# 在右键按住状态下移动时持续清除
	current_position = position
	var level_control = get_tree().get_first_node_in_group("level_control") as LevelControl
	if level_control:
		level_control.erase_at_position_immediate(position)

func handle_drag_event(position: Vector2):
	current_position = position
	input_dragged.emit(position)

# 公共方法 - 其他脚本可以调用的接口

## 检查是否正在点击
func is_input_active() -> bool:
	return is_clicking

## 检查是否右键正在按住
func is_right_input_active() -> bool:
	return is_right_clicking

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