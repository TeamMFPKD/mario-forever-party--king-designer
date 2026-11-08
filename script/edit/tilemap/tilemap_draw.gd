extends Node2D

class_name TileMapDraw

@export var tile_map: TileMapLayer

var is_drawing: bool = false
var brush_mode: bool = true # true for drawing, false for erasing
var drawing_enabled: bool = true
var custom_atlas_coords: Vector2i = Vector2i(-1, -1) # 自定义图块坐标，默认为(-1,-1)表示使用默认

# 地形笔刷预览（仅桌面端：鼠标悬停的格子上显示半透明图块）
const PREVIEW_ALPHA: float = 0.5
const PREVIEW_Z_INDEX: int = 10
const PREVIEW_NONE_CELL: Vector2i = Vector2i(-99999, -99999)
# InputHandler 用这个坐标表示“事件不在游戏视口内”
const INVALID_INPUT_POSITION: Vector2 = Vector2(-9999.0, -9999.0)

var _input_handler: InputHandler = null
var _preview_layer: TileMapLayer = null
var _preview_cell: Vector2i = PREVIEW_NONE_CELL

func _ready() -> void:
	# 延迟设置输入处理器，避免竞争条件
	call_deferred("setup_input_handler")

func setup_input_handler() -> void:
	# 检查是否已有输入处理器
	var input_handler: InputHandler = null
	
	# 首先尝试在场景树中查找InputHandler节点
	# 由于InputHandler位于Level节点下，而TileMapDraw位于Level/TileMapLayer/TileMapDraw
	# 所以应该向上查找两级到Level节点，然后查找其子节点
	var level_node: Node = get_parent().get_parent()  # 获取Level节点
	if level_node:
		for child: Node in level_node.get_children():
			if child is InputHandler:
				input_handler = child
				break
	
	if not input_handler:
		# 如果没有找到，尝试在整个场景树中查找
		for child: Node in get_tree().root.get_children():
			if child is InputHandler:
				input_handler = child
				break
	
	if not input_handler:
		# 如果还是没有，创建并添加到Level节点中
		var input_handler_script: GDScript = preload("uid://devgf5ccfvhwv")
		input_handler = input_handler_script.new()
		input_handler.name = "InputHandler"
		if level_node:
			level_node.call_deferred("add_child", input_handler)
			# 等待一帧让InputHandler完全初始化
			await get_tree().process_frame
			Log.i("TileMapDraw: InputHandler created and added to Level node")
		else:
			Log.i("TileMapDraw: Error: Cannot find Level node to add InputHandler")
			return
	
	if input_handler:
		# 连接输入信号
		if not input_handler.input_clicked.is_connected(_on_input_clicked):
			input_handler.input_clicked.connect(_on_input_clicked)
		if not input_handler.input_released.is_connected(_on_input_released):
			input_handler.input_released.connect(_on_input_released)
		if not input_handler.input_dragged.is_connected(_on_input_dragged):
			input_handler.input_dragged.connect(_on_input_dragged)
		_input_handler = input_handler
		Log.i("TileMapDraw: InputHandler signals connected successfully")
	else:
		Log.i("TileMapDraw: Error: Failed to find or create InputHandler")

# ---------------------------------------------------------------------------
# 地形笔刷预览（仅桌面端）
# 鼠标悬停的格子上显示将要放置的图块；地形使用自动连接时，
# 复制 3x3 邻域后交给引擎复算，预览与实际放下的图块一致。
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	var game_mode_node: GameMode = GameModeSingleton
	if game_mode_node.game_mode != GameMode.GameModeType.EDIT:
		_hide_preview()
		return
	if not PlatformUtils.is_desktop_platform():
		return
	if not drawing_enabled or not brush_mode or tile_map == null or tile_map.tile_set == null:
		_hide_preview()
		return
	if not InputHandler.is_pointer_inside_game_viewport(get_viewport()):
		_hide_preview()
		return

	var hover_position: Vector2 = INVALID_INPUT_POSITION
	if _input_handler:
		hover_position = _input_handler.current_position
	if hover_position == INVALID_INPUT_POSITION:
		_hide_preview()
		return

	var cell_size: Vector2i = tile_map.tile_set.tile_size
	var local_pos: Vector2 = to_local(hover_position)
	var cell: Vector2i = Vector2i(floori(local_pos.x / cell_size.x), floori(local_pos.y / cell_size.y))

	# 已经有图块的格子不会再放图块，不显示预览
	if tile_map.get_cell_source_id(cell) != -1:
		_hide_preview()
		return

	var preview: TileMapLayer = _get_preview_layer()
	if preview.tile_set != tile_map.tile_set:
		preview.tile_set = tile_map.tile_set
		_preview_cell = PREVIEW_NONE_CELL

	if cell == _preview_cell and preview.visible:
		return

	_preview_cell = cell
	_refresh_preview_cell(cell)
	preview.visible = true

func _get_preview_layer() -> TileMapLayer:
	if _preview_layer != null and is_instance_valid(_preview_layer):
		return _preview_layer

	_preview_layer = TileMapLayer.new()
	_preview_layer.name = "TilePlacementPreview"
	_preview_layer.z_index = PREVIEW_Z_INDEX
	_preview_layer.z_as_relative = false
	_preview_layer.modulate = Color(1.0, 1.0, 1.0, PREVIEW_ALPHA)
	_preview_layer.process_mode = Node.PROCESS_MODE_DISABLED
	# 预览格子逐帧瞬移，不参与物理插值，避免拖影
	_preview_layer.physics_interpolation_mode = CanvasItem.PHYSICS_INTERPOLATION_MODE_OFF
	_preview_layer.visible = false
	add_child(_preview_layer)
	return _preview_layer

func _hide_preview() -> void:
	if _preview_layer != null and is_instance_valid(_preview_layer):
		_preview_layer.visible = false

# 计算并显示悬停格子的预览图块：有自定义图块时直接使用；
# 否则用 3x3 邻域复算地形自动连接结果，只保留该格。
func _refresh_preview_cell(cell: Vector2i) -> void:
	if tile_map == null or tile_map.tile_set == null:
		return
	var preview: TileMapLayer = _get_preview_layer()
	if preview.tile_set != tile_map.tile_set:
		preview.tile_set = tile_map.tile_set
	preview.clear()

	if custom_atlas_coords != Vector2i(-1, -1):
		preview.set_cell(cell, 0, custom_atlas_coords)
		preview.reset_physics_interpolation()
		return

	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var neighbor: Vector2i = cell + Vector2i(dx, dy)
			var neighbor_source: int = tile_map.get_cell_source_id(neighbor)
			if neighbor_source == -1:
				continue
			preview.set_cell(neighbor, neighbor_source, tile_map.get_cell_atlas_coords(neighbor), tile_map.get_cell_alternative_tile(neighbor))

	preview.set_cells_terrain_connect([cell], 0, 0)
	var source_id: int = preview.get_cell_source_id(cell)
	var atlas_coords: Vector2i = preview.get_cell_atlas_coords(cell)
	var alternative: int = preview.get_cell_alternative_tile(cell)

	preview.clear()
	if source_id != -1:
		preview.set_cell(cell, source_id, atlas_coords, alternative)
	preview.reset_physics_interpolation()

func _on_input_clicked(input_pos: Vector2) -> void:
	if drawing_enabled and tile_map:
		# 点击时开始绘图
		is_drawing = true
		place_tile_at_cursor(input_pos)

func _on_input_released(_input_pos: Vector2) -> void:
	is_drawing = false

func _on_input_dragged(input_pos: Vector2) -> void:
	if drawing_enabled and is_drawing and tile_map:
		place_tile_at_cursor(input_pos)

# 设置绘图启用状态
func set_drawing_enabled(enabled: bool) -> void:
	drawing_enabled = enabled
	if not enabled:
		is_drawing = false

# 检查是否启用绘图
func is_drawing_enabled() -> bool:
	return drawing_enabled

# 开始绘图
func start_drawing() -> void:
	is_drawing = true

# 停止绘图
func stop_drawing() -> void:
	is_drawing = false

func place_tile_at_cursor(cursor_pos: Vector2) -> void:
	if not tile_map:
		return
	
	# 将世界坐标转换为本地坐标
	var local_pos: Vector2 = to_local(cursor_pos)
	
	# 获取单元格坐标
	var cell_size: Vector2i = tile_map.tile_set.tile_size
	var cell_coords: Vector2i = Vector2i(
		floori(local_pos.x / cell_size.x),
		floori(local_pos.y / cell_size.y)
	)

	var cell_coords_array: Array = [cell_coords]
	if brush_mode:
		# 放置瓦片 - 使用自定义图块坐标或默认设置
		if tile_map.get_cell_source_id(cell_coords) == -1:
			if custom_atlas_coords != Vector2i(-1, -1):
				# 使用自定义图块坐标
				tile_map.set_cell(cell_coords, 0, custom_atlas_coords)
				Log.i(["TileMapDraw: 放置自定义图块，坐标: ", custom_atlas_coords])
			else:
				# Draw Terrain - 使用默认地形连接
				tile_map.set_cells_terrain_connect(cell_coords_array, 0, 0)
				
				# 检查是否在Camera边界上，如果是则额外绘制terrain
				check_and_draw_border_terrain(cell_coords)
			
			# 发射放置音效信号
			emit_place_sound()
	else:
		# 擦除瓦片
		# 检查该位置是否有瓦片
		var has_tile: bool = tile_map.get_cell_source_id(cell_coords) != -1
		
		# 只有当存在瓦片时才擦除并播放音效
		if has_tile:
			tile_map.set_cells_terrain_connect(cell_coords_array, 0, -1)
			# 发射擦除音效信号
			emit_erase_sound()
			
			# 检查是否在Camera边界上，如果是则额外擦除边界外的terrain
			check_and_erase_border_terrain(cell_coords)
		
		# 在橡皮擦模式下，同时调用LevelControl的擦除功能来清除object
		call_level_control_erase(cursor_pos)

# 新增：发射放置音效的函数
func emit_place_sound() -> void:
	# 获取LevelControl节点并发射信号
	var level_node: Node = get_parent().get_parent()  # 获取Level节点
	if level_node:
		for child: Node in level_node.get_children():
			if child is LevelControl:
				child.emit_signal("play_sound_place")
				break

# 新增：发射擦除音效的函数
func emit_erase_sound() -> void:
	# 获取LevelControl节点并发射信号
	var level_node: Node = get_parent().get_parent()  # 获取Level节点
	if level_node:
		for child: Node in level_node.get_children():
			if child is LevelControl:
				child.emit_signal("play_sound_erase")
				break

# 在橡皮擦模式下调用LevelControl的擦除功能
func call_level_control_erase(input_pos: Vector2) -> void:
	# 获取LevelControl节点
	var level_node: Node = get_parent().get_parent()  # 获取Level节点
	if level_node:
		for child: Node in level_node.get_children():
			if child is LevelControl:
				# 调用LevelControl的擦除方法
				var level_control: LevelControl = child
				level_control.erase_at_position(input_pos)
				break

# 设置画笔模式（true为绘制，false为擦除）
func set_brush_mode(mode: bool) -> void:
	brush_mode = mode

# 获取当前画笔模式
func get_brush_mode() -> bool:
	return brush_mode

# 橡皮擦功能：在指定位置擦除瓦片
func erase_tile_at_position(input_pos: Vector2) -> void:
	if not tile_map:
		return
	
	# 将世界坐标转换为本地坐标
	var local_pos: Vector2 = to_local(input_pos)
	
	# 获取单元格坐标
	var cell_size: Vector2i = tile_map.tile_set.tile_size
	var cell_coords: Vector2i = Vector2i(
		floori(local_pos.x / cell_size.x),
		floori(local_pos.y / cell_size.y)
	)

	var cell_coords_array: Array = [cell_coords]
	
	# 检查该位置是否有瓦片
	var has_tile: bool = tile_map.get_cell_source_id(cell_coords) != -1
	
	# 只有当存在瓦片时才擦除并播放音效
	if has_tile:
		# 擦除瓦片
		tile_map.set_cells_terrain_connect(cell_coords_array, 0, -1)
		# 发射擦除音效信号
		emit_erase_sound()
		
		# 检查是否在Camera边界上，如果是则额外擦除边界外的terrain
		check_and_erase_border_terrain(cell_coords)

# 检查并擦除边界terrain（与check_and_draw_border_terrain对应的删除逻辑）
func check_and_erase_border_terrain(cell_coords: Vector2i) -> void:
	# 获取Camera2D
	var level_camera: Camera2D = get_tree().get_first_node_in_group("level_camera")
	if not level_camera:
		return
	
	# 获取Camera的边界限制
	var camera_left: int = level_camera.limit_left
	var camera_right: int = level_camera.limit_right
	var camera_top: int = level_camera.limit_top
	var camera_bottom: int = level_camera.limit_bottom
	
	# 获取单元格的世界坐标
	var cell_size: Vector2i = tile_map.tile_set.tile_size
	var cell_world_pos: Vector2 = Vector2(
		cell_coords.x * cell_size.x,
		cell_coords.y * cell_size.y
	)
	
	# 检查是否在边界上
	var is_on_left_border: bool = abs(cell_world_pos.x - camera_left) < cell_size.x
	var is_on_right_border: bool = abs((cell_world_pos.x + cell_size.x) - camera_right) < cell_size.x
	var is_on_top_border: bool = abs(cell_world_pos.y - camera_top) < cell_size.y
	var is_on_bottom_border: bool = abs((cell_world_pos.y + cell_size.y) - camera_bottom) < cell_size.x
	
	# 存储需要额外擦除的单元格坐标
	var extra_cells: Array[Vector2i] = []
	
	# 检查边界并添加对应的额外单元格
	if is_on_left_border:
		# 左侧边界：向左延伸一格
		extra_cells.append(Vector2i(cell_coords.x - 1, cell_coords.y))
		
		# 检查角落
		if is_on_top_border:
			# 左上角：向左上延伸一格
			extra_cells.append(Vector2i(cell_coords.x - 1, cell_coords.y - 1))
		if is_on_bottom_border:
			# 左下角：向左下延伸一格
			extra_cells.append(Vector2i(cell_coords.x - 1, cell_coords.y + 1))
	
	if is_on_right_border:
		# 右侧边界：向右延伸一格
		extra_cells.append(Vector2i(cell_coords.x + 1, cell_coords.y))
		
		# 检查角落
		if is_on_top_border:
			# 右上角：向右上延伸一格
			extra_cells.append(Vector2i(cell_coords.x + 1, cell_coords.y - 1))
		if is_on_bottom_border:
			# 右下角：向右下延伸一格
			extra_cells.append(Vector2i(cell_coords.x + 1, cell_coords.y + 1))
	
	if is_on_top_border:
		# 上侧边界：向上延伸一格
		extra_cells.append(Vector2i(cell_coords.x, cell_coords.y - 1))
	
	if is_on_bottom_border:
		# 下侧边界：向下延伸一格
		extra_cells.append(Vector2i(cell_coords.x, cell_coords.y + 1))
	
	# 擦除额外的terrain单元格
	for extra_cell: Vector2i in extra_cells:
		# 检查该位置是否有瓦片，如果有则擦除
		if tile_map.get_cell_source_id(extra_cell) != -1:
			tile_map.set_cells_terrain_connect([extra_cell], 0, -1)
			Log.i(["TileMapDraw: 在边界额外擦除terrain，坐标: ", extra_cell])

# 检查并绘制边界terrain
func check_and_draw_border_terrain(cell_coords: Vector2i) -> void:
	# 获取Camera2D
	var level_camera: Camera2D = get_tree().get_first_node_in_group("level_camera")
	if not level_camera:
		return
	
	# 获取Camera的边界限制
	var camera_left: int = level_camera.limit_left
	var camera_right: int = level_camera.limit_right
	var camera_top: int = level_camera.limit_top
	var camera_bottom: int = level_camera.limit_bottom
	
	# 获取单元格的世界坐标
	var cell_size: Vector2i = tile_map.tile_set.tile_size
	var cell_world_pos: Vector2 = Vector2(
		cell_coords.x * cell_size.x,
		cell_coords.y * cell_size.y
	)
	
	# 检查是否在边界上
	var is_on_left_border: bool = abs(cell_world_pos.x - camera_left) < cell_size.x
	var is_on_right_border: bool = abs((cell_world_pos.x + cell_size.x) - camera_right) < cell_size.x
	var is_on_top_border: bool = abs(cell_world_pos.y - camera_top) < cell_size.y
	var is_on_bottom_border: bool = abs((cell_world_pos.y + cell_size.y) - camera_bottom) < cell_size.x
	
	# 存储需要额外绘制的单元格坐标
	var extra_cells: Array[Vector2i] = []
	
	# 检查边界并添加对应的额外单元格
	if is_on_left_border:
		# 左侧边界：向左延伸一格
		extra_cells.append(Vector2i(cell_coords.x - 1, cell_coords.y))
		
		# 检查角落
		if is_on_top_border:
			# 左上角：向左上延伸一格
			extra_cells.append(Vector2i(cell_coords.x - 1, cell_coords.y - 1))
		if is_on_bottom_border:
			# 左下角：向左下延伸一格
			extra_cells.append(Vector2i(cell_coords.x - 1, cell_coords.y + 1))
	
	if is_on_right_border:
		# 右侧边界：向右延伸一格
		extra_cells.append(Vector2i(cell_coords.x + 1, cell_coords.y))
		
		# 检查角落
		if is_on_top_border:
			# 右上角：向右上延伸一格
			extra_cells.append(Vector2i(cell_coords.x + 1, cell_coords.y - 1))
		if is_on_bottom_border:
			# 右下角：向右下延伸一格
			extra_cells.append(Vector2i(cell_coords.x + 1, cell_coords.y + 1))
	
	if is_on_top_border:
		# 上侧边界：向上延伸一格
		extra_cells.append(Vector2i(cell_coords.x, cell_coords.y - 1))
	
	if is_on_bottom_border:
		# 下侧边界：向下延伸一格
		extra_cells.append(Vector2i(cell_coords.x, cell_coords.y + 1))
	
	# 绘制额外的terrain单元格
	for extra_cell: Vector2i in extra_cells:
		# 检查该位置是否已经有瓦片，如果没有则绘制
		if tile_map.get_cell_source_id(extra_cell) == -1:
			tile_map.set_cells_terrain_connect([extra_cell], 0, 0)
			Log.i(["TileMapDraw: 在边界额外绘制terrain，坐标: ", extra_cell])

# 设置自定义图块坐标
func set_custom_atlas_coords(coords: Vector2i) -> void:
	custom_atlas_coords = coords
	Log.i(["TileMapDraw: 设置自定义图块坐标为: ", coords])

# 清除自定义图块坐标，恢复默认行为
func clear_custom_atlas_coords() -> void:
	custom_atlas_coords = Vector2i(-1, -1)
	Log.i("TileMapDraw: 清除自定义图块坐标，恢复默认行为")
