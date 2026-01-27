extends Node

class_name LevelControl

enum DrawingMode {
	TILEMAP,
	OBJECTMAP,
	ERASER
}

# 信号
signal drawing_mode_changed(mode: DrawingMode)
signal object_selected(object_name: String)

# 当前绘图模式
var current_drawing_mode: DrawingMode = DrawingMode.TILEMAP
var current_object_name: String = ""

# 节点引用
@export var tile_map_draw: Node
@export var object_map_layer: ObjectMapLayer
@export var object_map_draw: Node

# 按钮引用（只保留非ItemButton的按钮）
@export var tile_button: Button
@export var button_eraser: Button

func _ready():
	# 连接按钮信号
	if tile_button:
		print("LevelControl: 找到tile_button，准备连接信号")
		tile_button.pressed.connect(_on_tile_button_pressed)
		print("LevelControl: tile_button信号连接完成")
	else:
		print("LevelControl: 错误：tile_button未找到")
	
	if button_eraser:
		print("LevelControl: 找到button_eraser，准备连接信号")
		button_eraser.pressed.connect(_on_eraser_button_pressed)
		print("LevelControl: button_eraser信号连接完成")
	else:
		print("LevelControl: 错误：button_eraser未找到")
	
	# 初始化模式
	switch_to_tilemap_mode()

func switch_to_tilemap_mode():
	current_drawing_mode = DrawingMode.TILEMAP
	current_object_name = ""
	
	# 启用TileMap绘制，禁用ObjectMap绘制和橡皮擦
	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(true)
		if tile_map_draw.has_method("set_brush_mode"):
			tile_map_draw.set_brush_mode(true)  # 设置为绘制模式
		
		# 清除自定义图块坐标，恢复默认行为
		if tile_map_draw.has_method("clear_custom_atlas_coords"):
			tile_map_draw.clear_custom_atlas_coords()
	
	if object_map_layer and object_map_layer.has_method("stop_placing_object"):
		object_map_layer.stop_placing_object()
		object_map_layer.drawing_enabled = false
	
	# 发出信号
	drawing_mode_changed.emit(current_drawing_mode)
	
	print("切换到TileMap绘图模式")

# 切换到对象地图模式（通过对象名称）
func switch_to_objectmap_mode(object_name: String):
	current_drawing_mode = DrawingMode.OBJECTMAP
	current_object_name = object_name
	
	# 禁用TileMap绘制，启用ObjectMap绘制
	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(false)
	
	if object_map_layer and object_map_layer.has_method("start_placing_object"):
		object_map_layer.start_placing_object(object_name)
		object_map_layer.drawing_enabled = true

	
	# 发出信号
	drawing_mode_changed.emit(current_drawing_mode)
	object_selected.emit(object_name)
	
	print("切换到ObjectMap绘图模式，对象名称: ", object_name)

func switch_to_eraser_mode():
	current_drawing_mode = DrawingMode.ERASER
	current_object_name = ""
	
	# 启用TileMap绘制但设置为擦除模式，禁用ObjectMap绘制
	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(true)
		if tile_map_draw.has_method("set_brush_mode"):
			tile_map_draw.set_brush_mode(false)  # 设置为擦除模式
	
	if object_map_layer and object_map_layer.has_method("stop_placing_object"):
		object_map_layer.stop_placing_object()
		object_map_layer.drawing_enabled = false

	
	# 发出信号
	drawing_mode_changed.emit(current_drawing_mode)
	
	print("切换到橡皮擦模式")


func _on_tile_button_pressed():
	switch_to_tilemap_mode()

func _on_eraser_button_pressed():
	switch_to_eraser_mode()

# 切换到TileMap绘图模式（支持自定义图块坐标）
func switch_to_tilemap_mode_with_coords(custom_atlas_coords: Vector2i = Vector2i(-1, -1)):
	current_drawing_mode = DrawingMode.TILEMAP
	current_object_name = ""
	
	# 启用TileMap绘制，禁用ObjectMap绘制和橡皮擦
	if tile_map_draw and tile_map_draw.has_method("set_drawing_enabled"):
		tile_map_draw.set_drawing_enabled(true)
		if tile_map_draw.has_method("set_brush_mode"):
			tile_map_draw.set_brush_mode(true)  # 设置为绘制模式
		
		# 设置自定义图块坐标（如果提供）
		if custom_atlas_coords != Vector2i(-1, -1) and tile_map_draw.has_method("set_custom_atlas_coords"):
			tile_map_draw.set_custom_atlas_coords(custom_atlas_coords)
		else:
			# 清除自定义图块坐标
			if tile_map_draw.has_method("clear_custom_atlas_coords"):
				tile_map_draw.clear_custom_atlas_coords()
	
	if object_map_layer and object_map_layer.has_method("stop_placing_object"):
		object_map_layer.stop_placing_object()
		object_map_layer.drawing_enabled = false
	
	
	# 发出信号
	drawing_mode_changed.emit(current_drawing_mode)
	
	print("切换到TileMap绘图模式", 
		  " (自定义图块坐标: ", custom_atlas_coords, ")" if custom_atlas_coords != Vector2i(-1, -1) else "")

# 获取当前绘图模式
func get_current_drawing_mode() -> DrawingMode:
	return current_drawing_mode

# 获取当前选中的对象名称
func get_current_object_name() -> String:
	return current_object_name

# 检查是否在TileMap模式
func is_tilemap_mode() -> bool:
	return current_drawing_mode == DrawingMode.TILEMAP

# 检查是否在ObjectMap模式
func is_objectmap_mode() -> bool:
	return current_drawing_mode == DrawingMode.OBJECTMAP

# 检查是否在橡皮擦模式
func is_eraser_mode() -> bool:
	return current_drawing_mode == DrawingMode.ERASER

# 橡皮擦功能：在指定位置清除Tile和Object（受当前模式限制）
func erase_at_position(position: Vector2):
	if current_drawing_mode != DrawingMode.ERASER:
		return
	
	# 清除Tile
	if tile_map_draw and tile_map_draw.has_method("erase_tile_at_position"):
		tile_map_draw.erase_tile_at_position(position)
	
	# 清除Object
	if object_map_layer and object_map_layer.has_method("remove_object_at_position"):
		object_map_layer.remove_object_at_position(position)
	
	print("橡皮擦：清除位置 ", position)

# 新增：不受模式限制的清除功能（用于右键点击）
func erase_at_position_immediate(position: Vector2):
	# 不检查当前模式，直接清除Tile和Object
	# 清除Tile
	if tile_map_draw and tile_map_draw.has_method("erase_tile_at_position"):
		tile_map_draw.erase_tile_at_position(position)
	
	# 清除Object
	if object_map_layer and object_map_layer.has_method("remove_object_at_position"):
		object_map_layer.remove_object_at_position(position)
	
	print("右键清除：清除位置 ", position)

# 处理ItemButton的按下事件
func _on_item_button_pressed(item_type: ItemButton.ItemType, button: ItemButton):
	var object_name = ""  # 在函数开头定义object_name变量
	
	match item_type:
		ItemButton.ItemType.TILE:
			# 检查按钮名称，为不同的Tile按钮设置不同的图块坐标
			if "TileSingle" in button.name:
				# ItemButtonTileSingle按钮，设置atlas_coords为(0, 4)
				switch_to_tilemap_mode_with_coords(Vector2i(0, 4))
			elif "TileSemiSolid" in button.name:
				# ItemButtonTileSemiSolid按钮，设置atlas_coords为(1, 4)
				switch_to_tilemap_mode_with_coords(Vector2i(1, 4))
			else:
				# 其他Tile按钮，使用默认行为
				switch_to_tilemap_mode()
		ItemButton.ItemType.OBJECT:
			# 使用按钮的object_name属性
			object_name = button.object_name
			if object_name == "":
				# 如果object_name为空，使用按钮名称作为默认值
				object_name = button.name.replace("ItemButton", "").to_lower()
				print("警告：ItemButton ", button.name, " 的object_name为空，使用默认名称: ", object_name)
			
			switch_to_objectmap_mode(object_name)
		ItemButton.ItemType.ERASER:
			switch_to_eraser_mode()
	
	print("ItemButton按下: ", button.name, " 类型: ", item_type, " 对象名称: ", object_name)
