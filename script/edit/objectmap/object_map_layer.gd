extends Node2D

class_name ObjectMapLayer

@export var objects : Array = []
@export var database_holder: DatabaseHolder

# 输入处理相关变量
var is_placing = false
var current_object_name = ""
var drawing_enabled = false

func _ready():
	# 确保有输入处理器
	setup_input_handler()

	# 祖传玩家位置
	if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.EDIT:
		return
	current_object_name = "player"
	if not database_holder or not database_holder.object_database or current_object_name == "":
		return
	
	# 查找对应的对象条目
	var entry = find_object_by_name(current_object_name)
	if not entry or not entry.object_scene:
		print("[%s] ObjectMapLayer: 未找到对象: " % Time.get_time_string_from_system(), current_object_name)
		return
	
	# 如果是player对象，先删除所有已存在的player对象
	if current_object_name == "player":
		remove_all_objects_of_type("player")
		print("[%s] ObjectMapLayer: 放置player前已清除所有已存在的player对象" % Time.get_time_string_from_system())
	
	# 将位置对齐到32x32网格
	var grid_position = align_to_grid(Vector2(112.0, 400.0))
	
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
		var input_handler_script = preload("uid://devgf5ccfvhwv")
		input_handler = input_handler_script.new()
		input_handler.name = "InputHandler"
		get_parent().call_deferred("add_child", input_handler)
		# 等待一帧让InputHandler完全初始化
		await get_tree().process_frame
		print("[%s] ObjectMapLayer: InputHandler created and added to parent" % Time.get_time_string_from_system())
	
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
		# 新增：连接拖拽信号
		if not input_handler.input_dragged.is_connected(_on_input_dragged):
			input_handler.input_dragged.connect(_on_input_dragged)
		print("[%s] ObjectMapLayer: InputHandler signals connected successfully" % Time.get_time_string_from_system())
	else:
		print("[%s] ObjectMapLayer: Error: Failed to find or create InputHandler" % Time.get_time_string_from_system())

func _on_input_clicked(input_pos: Vector2):
	if drawing_enabled and database_holder and database_holder.object_database and current_object_name != "":
		place_object_at_position(input_pos, true)

# 新增：处理拖拽事件
func _on_input_dragged(input_pos: Vector2):
	if drawing_enabled and database_holder and database_holder.object_database and current_object_name != "":
		# 将位置对齐到网格
		var grid_position = align_to_grid(input_pos)
		# 检查该网格位置是否已有对象
		if not is_grid_position_occupied(grid_position):
			place_object_at_position(input_pos, false)

func _on_input_released(_input_pos: Vector2):
	is_placing = false

# 在指定位置放置对象
func place_object_at_position(input_pos: Vector2, check_duplicate: bool = true):
	if not database_holder or not database_holder.object_database or current_object_name == "":
		return
	
	# 查找对应的对象条目
	var entry = find_object_by_name(current_object_name)
	if not entry or not entry.object_scene:
		print("ObjectMapLayer: 未找到对象: ", current_object_name)
		return
	
	# 将位置对齐到32x32网格
	var grid_position = align_to_grid(input_pos)
	
	# 检查该网格位置是否已有对象（仅在需要时检查）
	if check_duplicate and is_grid_position_occupied(grid_position):
		print("[%s] ObjectMapLayer: 该网格位置已有对象，不进行绘制" % Time.get_time_string_from_system())
		return
	
	# 如果是player对象，先删除所有已存在的player对象
	if current_object_name == "player":
		remove_all_objects_of_type("player")
		print("ObjectMapLayer: 放置player前已清除所有已存在的player对象")
	
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
		
		print("[%s] 放置对象: " % Time.get_time_string_from_system(), entry.object_name, " 在网格位置: ", grid_position)
		
		# 发射放置音效信号
		emit_place_sound()

# 新增：发射放置音效的函数
func emit_place_sound():
	# 获取LevelControl节点并发射信号
	var level_node = get_tree().get_first_node_in_group("level_control") as LevelControl
	if is_instance_valid(level_node):
		level_node.emit_signal("play_sound_place")


# 公共方法：开始放置对象（通过对象名称）
func start_placing_object(object_name: String):
	if database_holder and database_holder.object_database:
		current_object_name = object_name
		is_placing = true
		drawing_enabled = true
		print("ObjectMapLayer: 开始放置对象，名称: ", object_name)

# 公共方法：停止放置对象
func stop_placing_object():
	is_placing = false
	drawing_enabled = false
	current_object_name = ""
	print("ObjectMapLayer: 停止放置对象")

# 将位置对齐到32x32网格
func align_to_grid(input_pos: Vector2) -> Vector2:
	var grid_size = 32
	return Vector2(
		floor(input_pos.x / grid_size) * grid_size + grid_size / 2.0,
		floor(input_pos.y / grid_size) * grid_size + grid_size / 2.0
	)

# 检查网格位置是否已有对象
func is_grid_position_occupied(grid_position: Vector2) -> bool:
	for object_data in objects:
		if object_data.has("position") and object_data["position"] == grid_position:
			return true
	return false

# 通过对象名称查找对应的数据库条目
func find_object_by_name(object_name: String) -> ObjectDatabaseEntry:
	if not database_holder or not database_holder.object_database:
		return null
	
	for entry in database_holder.object_database.object_database_entry:
		if entry and entry.object_name == object_name:
			return entry
	
	return null

# 移除指定位置的对象
func remove_object_at_position(input_pos: Vector2):
	var grid_position = align_to_grid(input_pos)
	var object_to_remove = null
	
	for object_data in objects:
		if object_data.has("position") and object_data["position"] == grid_position:
			object_to_remove = object_data
			break
	
	if object_to_remove:
		if object_to_remove.has("object_name") and object_to_remove["object_name"] == "player":
			return false
		if object_to_remove.has("instance") and is_instance_valid(object_to_remove["instance"]):
			object_to_remove["instance"].queue_free()
		objects.erase(object_to_remove)
		print("[%s] 橡皮擦：清除对象在位置 " % Time.get_time_string_from_system(), grid_position)
		return true
	
	#print("橡皮擦：位置 ", grid_position, " 没有对象")
	return false

# 获取指定位置的对象
func get_object_at_position(input_pos: Vector2) -> Dictionary:
	var grid_position = align_to_grid(input_pos)
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

# 删除特定类型的所有对象
func remove_all_objects_of_type(object_name: String):
	var objects_to_remove = []
	for object_data in objects:
		if object_data.has("object_name") and object_data["object_name"] == object_name:
			objects_to_remove.append(object_data)
	
	for object_data in objects_to_remove:
		if object_data.has("instance") and is_instance_valid(object_data["instance"]):
			object_data["instance"].queue_free()
		objects.erase(object_data)
	
	print("[%s] 已删除所有类型为 '" % Time.get_time_string_from_system(), object_name, "' 的对象，共删除 ", objects_to_remove.size(), " 个")

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
		var obj_position = Vector2(save_object["position"]["x"], save_object["position"]["y"])
		
		# 在数据库中查找对应的对象
		if database_holder and database_holder.object_database:
			current_object_name = object_name
			place_object_at_position(obj_position, true)