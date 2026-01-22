extends Node2D

class_name ObjectMapLayer

@export var objects : Array = []
@export var database_holder: DatabaseHolder

# 输入处理相关变量
var is_placing = false
var current_object_index = 0
var drawing_enabled = false

func _ready():
	# 确保有输入处理器
	setup_input_handler()

func setup_input_handler():
	# 检查是否已有输入处理器
	var input_handler = null
	
	# 首先尝试在场景树中查找InputHandler节点
	for child in get_tree().root.get_children():
		if child is InputHandler:
			input_handler = child
			break
	
	if not input_handler:
		# 如果没有，创建并添加到当前节点的父节点中
		var input_handler_script = preload("res://script/input_handler.gd")
		input_handler = input_handler_script.new()
		input_handler.name = "InputHandler"
		get_parent().call_deferred("add_child", input_handler)
		# 等待一帧让InputHandler完全初始化
		await get_tree().process_frame
		print("ObjectMapLayer: InputHandler created and added to parent")
	
	# 重新获取InputHandler引用
	input_handler = null
	for child in get_parent().get_children():
		if child is InputHandler:
			input_handler = child
			break
	
	if input_handler:
		# 连接输入信号
		if not input_handler.input_clicked.is_connected(_on_input_clicked):
			input_handler.input_clicked.connect(_on_input_clicked)
		if not input_handler.input_released.is_connected(_on_input_released):
			input_handler.input_released.connect(_on_input_released)
		print("ObjectMapLayer: InputHandler signals connected successfully")
	else:
		print("ObjectMapLayer: Error: Failed to find or create InputHandler")

func _on_input_clicked(position: Vector2):
	if drawing_enabled and database_holder and database_holder.object_database and database_holder.object_database.object_database_entry.size() > current_object_index:
		place_object_at_position(position)

func _on_input_released(position: Vector2):
	is_placing = false

# 公共方法：开始放置对象
func start_placing_object(object_index: int):
	if database_holder and database_holder.object_database and database_holder.object_database.object_database_entry.size() > object_index:
		current_object_index = object_index
		is_placing = true
		drawing_enabled = true
		print("ObjectMapLayer: 开始放置对象，索引: ", object_index)

# 公共方法：停止放置对象
func stop_placing_object():
	is_placing = false
	drawing_enabled = false
	print("ObjectMapLayer: 停止放置对象")

# 将位置对齐到32x32网格
func align_to_grid(position: Vector2) -> Vector2:
	var grid_size = 32
	return Vector2(
		floor(position.x / grid_size) * grid_size + grid_size / 2,
		floor(position.y / grid_size) * grid_size + grid_size / 2
	)

# 检查网格位置是否已有对象
func is_grid_position_occupied(grid_position: Vector2) -> bool:
	for object_data in objects:
		if object_data.has("position") and object_data["position"] == grid_position:
			return true
	return false

# 在指定位置放置对象
func place_object_at_position(position: Vector2):
	if not database_holder or not database_holder.object_database or current_object_index >= database_holder.object_database.object_database_entry.size():
		return
	
	# 将位置对齐到32x32网格
	var grid_position = align_to_grid(position)
	
	# 检查该网格位置是否已有对象
	if is_grid_position_occupied(grid_position):
		print("ObjectMapLayer: 该网格位置已有对象，不进行绘制")
		return
	
	var entry = database_holder.object_database.object_database_entry[current_object_index]
	if entry and entry.object_scene:
		var scene_instance = entry.object_scene.instantiate()
		if scene_instance is Node2D:
			scene_instance.global_position = grid_position
			add_child(scene_instance)
			
			# 保存对象信息
			var object_data = {
				"object_name": entry.object_name,
				"object_scene": entry.object_scene,
				"position": grid_position,
				"instance": scene_instance
			}
			objects.append(object_data)
			
			print("放置对象: ", entry.object_name, " 在网格位置: ", grid_position)

# 移除指定位置的对象
func remove_object_at_position(position: Vector2):
	var grid_position = align_to_grid(position)
	var object_to_remove = null
	
	for object_data in objects:
		if object_data.has("position") and object_data["position"] == grid_position:
			object_to_remove = object_data
			break
	
	if object_to_remove:
		if object_to_remove.has("instance") and is_instance_valid(object_to_remove["instance"]):
			object_to_remove["instance"].queue_free()
		objects.erase(object_to_remove)
		print("橡皮擦：清除对象在位置 ", grid_position)
		return true
	
	print("橡皮擦：位置 ", grid_position, " 没有对象")
	return false

# 获取指定位置的对象
func get_object_at_position(position: Vector2) -> Dictionary:
	var grid_position = align_to_grid(position)
	for object_data in objects:
		if object_data.has("position") and object_data["position"] == grid_position:
			return object_data
	return {}

# 清空所有对象
func clear_all_objects():
	for object_data in objects:
		if object_data.has("instance") and is_instance_valid(object_data["instance"]):
			object_data["instance"].queue_free()
	objects.clear()

# 保存对象数据（用于关卡保存）
func get_object_data() -> Array:
	var save_data = []
	for object_data in objects:
		var save_object = {
			"object_name": object_data["object_name"],
			"position": {
				"x": object_data["position"].x,
				"y": object_data["position"].y
			}
		}
		save_data.append(save_object)
	return save_data

# 加载对象数据（用于关卡加载）
func load_object_data(object_data: Array):
	clear_all_objects()
	
	for save_object in object_data:
		var object_name = save_object["object_name"]
		var position = Vector2(save_object["position"]["x"], save_object["position"]["y"])
		
		# 在数据库中查找对应的对象
		if database_holder and database_holder.object_database:
			for i in range(database_holder.object_database.object_database_entry.size()):
				var entry = database_holder.object_database.object_database_entry[i]
				if entry.object_name == object_name:
					current_object_index = i
					place_object_at_position(position)
					break
