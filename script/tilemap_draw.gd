extends Node2D

class_name TileMapDraw

@export var tile_map: TileMapLayer

var is_drawing = false
var brush_mode = true # true for drawing, false for erasing
var drawing_enabled = true

func _ready():
	# 延迟设置输入处理器，避免竞争条件
	call_deferred("setup_input_handler")

func setup_input_handler():
	# 检查是否已有输入处理器
	var input_handler = null
	
	# 首先尝试在场景树中查找InputHandler节点
	# 由于InputHandler位于Level节点下，而TileMapDraw位于Level/TileMapLayer/TileMapDraw
	# 所以应该向上查找两级到Level节点，然后查找其子节点
	var level_node = get_parent().get_parent()  # 获取Level节点
	if level_node:
		for child in level_node.get_children():
			if child is InputHandler:
				input_handler = child
				break
	
	if not input_handler:
		# 如果没有找到，尝试在整个场景树中查找
		for child in get_tree().root.get_children():
			if child is InputHandler:
				input_handler = child
				break
	
	if not input_handler:
		# 如果还是没有，创建并添加到Level节点中
		var input_handler_script = preload("res://script/input_handler.gd")
		input_handler = input_handler_script.new()
		input_handler.name = "InputHandler"
		if level_node:
			level_node.call_deferred("add_child", input_handler)
			# 等待一帧让InputHandler完全初始化
			await get_tree().process_frame
			print("TileMapDraw: InputHandler created and added to Level node")
		else:
			print("TileMapDraw: Error: Cannot find Level node to add InputHandler")
			return
	
	if input_handler:
		# 连接输入信号
		if not input_handler.input_clicked.is_connected(_on_input_clicked):
			input_handler.input_clicked.connect(_on_input_clicked)
		if not input_handler.input_released.is_connected(_on_input_released):
			input_handler.input_released.connect(_on_input_released)
		if not input_handler.input_dragged.is_connected(_on_input_dragged):
			input_handler.input_dragged.connect(_on_input_dragged)
		print("TileMapDraw: InputHandler signals connected successfully")
	else:
		print("TileMapDraw: Error: Failed to find or create InputHandler")

func _on_input_clicked(position: Vector2):
	if drawing_enabled and tile_map:
		# 点击时开始绘图
		is_drawing = true
		place_tile_at_cursor(position)

func _on_input_released(position: Vector2):
	is_drawing = false

func _on_input_dragged(position: Vector2):
	if drawing_enabled and is_drawing and tile_map:
		place_tile_at_cursor(position)

# 设置绘图启用状态
func set_drawing_enabled(enabled: bool):
	drawing_enabled = enabled
	if not enabled:
		is_drawing = false

# 检查是否启用绘图
func is_drawing_enabled() -> bool:
	return drawing_enabled

# 开始绘图
func start_drawing():
	is_drawing = true

# 停止绘图
func stop_drawing():
	is_drawing = false

func place_tile_at_cursor(cursor_pos):
	if not tile_map:
		return
	
	# 将世界坐标转换为本地坐标
	var local_pos = to_local(cursor_pos)
	
	# 获取单元格坐标
	var cell_size = tile_map.tile_set.tile_size
	var cell_coords = Vector2i(
		floor(local_pos.x / cell_size.x),
		floor(local_pos.y / cell_size.y)
	)

	var cell_coords_array: Array = [cell_coords]
	if brush_mode:
		# 放置瓦片 - 使用正确的 Godot 4 API 参数顺序
		if tile_map.get_cell_source_id(cell_coords) == -1:
			# Draw Enemy
			#tile_map.set_cell(cell_coords, 1, Vector2i(0, 0), 2)
			# Draw Terrain
			tile_map.set_cells_terrain_connect(cell_coords_array, 0, 0)
	else:
		# 擦除瓦片
		tile_map.set_cells_terrain_connect(cell_coords_array, 0, -1)
		
		# 在橡皮擦模式下，同时调用LevelControl的擦除功能来清除object
		call_level_control_erase(cursor_pos)

# 在橡皮擦模式下调用LevelControl的擦除功能
func call_level_control_erase(position: Vector2):
	# 获取LevelControl节点
	var level_node = get_parent().get_parent()  # 获取Level节点
	if level_node:
		for child in level_node.get_children():
			if child is LevelControl:
				# 调用LevelControl的擦除方法
				child.erase_at_position(position)
				break

# 设置画笔模式（true为绘制，false为擦除）
func set_brush_mode(mode: bool):
	brush_mode = mode

# 获取当前画笔模式
func get_brush_mode() -> bool:
	return brush_mode

# 橡皮擦功能：在指定位置擦除瓦片
func erase_tile_at_position(position: Vector2):
	if not tile_map:
		return
	
	# 将世界坐标转换为本地坐标
	var local_pos = to_local(position)
	
	# 获取单元格坐标
	var cell_size = tile_map.tile_set.tile_size
	var cell_coords = Vector2i(
		floor(local_pos.x / cell_size.x),
		floor(local_pos.y / cell_size.y)
	)

	var cell_coords_array: Array = [cell_coords]
	# 擦除瓦片
	tile_map.set_cells_terrain_connect(cell_coords_array, 0, -1)