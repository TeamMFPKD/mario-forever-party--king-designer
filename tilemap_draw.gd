extends Node2D

var tile_map: TileMapLayer
var is_drawing = false
var brush_mode = false # true for drawing, false for erasing

func _ready():
	tile_map = get_node("TileMapLayer") as TileMapLayer
	if tile_map:
		print("TileMapLayer found and assigned.")
	else:
		print("Error: TileMapLayer not found as child of this node.")


func _input(event):
	if not tile_map:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_drawing = event.pressed
			if is_drawing:
				place_tile_at_cursor(event.position)
	elif event is InputEventMouseMotion:
		if is_drawing:
			place_tile_at_cursor(event.position)
	elif event is InputEventScreenTouch:
		is_drawing = event.pressed
		if is_drawing:
			place_tile_at_cursor(event.position)
	elif event is InputEventScreenDrag:
		if is_drawing:
			place_tile_at_cursor(event.position)


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
			tile_map.set_cell(cell_coords, 1, Vector2i(0, 0), 2)
			# Draw Terrain
			#tile_map.set_cells_terrain_connect(cell_coords_array, 0, 0)
	else:
		# 擦除瓦片
		tile_map.set_cells_terrain_connect(cell_coords_array, 0, -1)

# 用于切换绘制模式的函数
func toggle_brush_mode():
	brush_mode = !brush_mode
	print("Brush mode changed to: ", "Draw" if brush_mode else "Erase")
