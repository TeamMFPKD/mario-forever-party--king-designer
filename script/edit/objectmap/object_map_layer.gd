extends Node2D

class_name ObjectMapLayer

signal play_sound_drag

@export var objects : Array = []
@export var database_holder: DatabaseHolder

# 输入处理相关变量
var is_placing = false
var current_object_name = ""
var drawing_enabled = false

# 门ID计数器
var _door_id_counter: int = 1
# 最大门组数
const MAX_DOOR_GROUPS: int = 4
# 每组门数量
const DOORS_PER_GROUP: int = 2

# 拖动相关变量
var _dragging_object: Dictionary = {}
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_original_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

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

func _update_drag(world_pos: Vector2) -> void:
	if not _is_dragging or _dragging_object.is_empty():
		return
	
	var new_grid_pos = align_to_grid(world_pos)
	var current_pos = _dragging_object.get("position", Vector2.ZERO)
	
	if new_grid_pos == current_pos:
		return
	
	for object_data in objects:
		if object_data == _dragging_object:
			continue
		if object_data.has("position") and object_data["position"] == new_grid_pos:
			print("[%s] 拖动被阻止：目标位置已有对象" % Time.get_time_string_from_system())
			return
	
	var instance = _dragging_object.get("instance")
	if instance and is_instance_valid(instance):
		instance.global_position = new_grid_pos
		_dragging_object["position"] = new_grid_pos
		print("[%s] 拖动更新位置: " % Time.get_time_string_from_system(), current_pos, " -> ", new_grid_pos)
		emit_signal("play_sound_drag")

func _finish_drag() -> void:
	if not _is_dragging:
		return
	
	print("[%s] 拖动结束" % Time.get_time_string_from_system())
	_is_dragging = false
	
	if _dragging_object.is_empty():
		return
	
	var new_pos = _dragging_object.get("position", _drag_original_pos)
	
	if _dragging_object.get("object_name") == "door":
		_on_door_dragged(_dragging_object, new_pos)
	
	_dragging_object = {}

func _on_door_dragged(door_data: Dictionary, new_pos: Vector2) -> void:
	var door_id = door_data.get("door_id", -1)
	if door_id == -1:
		return
	
	for object_data in objects:
		if object_data.get("door_id", -1) == door_id and object_data != door_data:
			if object_data.has("instance") and is_instance_valid(object_data["instance"]):
				print("[%s] 门拖动：同组门ID %d 位置更新" % [Time.get_time_string_from_system(), door_id])

func _on_input_clicked(input_pos: Vector2):
	if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.EDIT:
		return
	
	var grid_pos = align_to_grid(input_pos)
	
	for object_data in objects:
		if object_data.has("instance") and is_instance_valid(object_data["instance"]):
			var obj_pos = object_data["position"]
			if abs(obj_pos.x - grid_pos.x) < 16.0 and abs(obj_pos.y - grid_pos.y) < 16.0:
				_dragging_object = object_data
				_drag_start_pos = input_pos
				_drag_original_pos = object_data["position"]
				_is_dragging = true
				print("[%s] 开始拖动对象: " % Time.get_time_string_from_system(), object_data.get("object_name", "unknown"), " 位置: ", obj_pos)
				return
	
	if drawing_enabled and database_holder and database_holder.object_database and current_object_name != "":
		place_object_at_position(input_pos, true)

# 新增：处理拖拽事件
func _on_input_dragged(input_pos: Vector2):
	if _is_dragging:
		_update_drag(input_pos)
	elif drawing_enabled and database_holder and database_holder.object_database and current_object_name != "":
		var grid_position = align_to_grid(input_pos)
		if not is_grid_position_occupied(grid_position):
			place_object_at_position(input_pos, false)

func _on_input_released(_input_pos: Vector2):
	if _is_dragging:
		_finish_drag()
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
	
	# 如果是门对象，先检查数量限制
	if current_object_name == "door":
		var door_count = _get_door_count()
		if door_count >= MAX_DOOR_GROUPS * DOORS_PER_GROUP:
			print("[%s] ObjectMapLayer: 已达到最大门数量限制 (%d个)" % [Time.get_time_string_from_system(), MAX_DOOR_GROUPS * DOORS_PER_GROUP])
			return
	
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
		
		# 如果是门对象，需要成对放置
		if current_object_name == "door":
			_place_paired_door(scene_instance, grid_position, entry)
		
		# 发射放置音效信号
		emit_place_sound()

# 成对放置门
func _place_paired_door(first_door: Node2D, first_position: Vector2, entry: ObjectDatabaseEntry):
	_door_id_counter += 1
	var door_id = _door_id_counter
	
	# 设置第一个门的ID
	_set_door_id(first_door, door_id)
	
	# 更新第一个门的object_data，添加door_id
	for i in range(objects.size()):
		var obj = objects[i]
		if obj.get("instance") == first_door:
			objects[i]["door_id"] = door_id
			break
	
	# 计算第二个门的位置（相邻格子）
	var second_position = first_position + Vector2(32, 0)  # 右边相邻格子
	
	# 检查第二个位置是否已有对象
	if is_grid_position_occupied(second_position):
		second_position = first_position + Vector2(0, -32)  # 上边相邻格子
		if is_grid_position_occupied(second_position):
			second_position = first_position + Vector2(-32, 0)  # 左边相邻格子
			if is_grid_position_occupied(second_position):
				second_position = first_position + Vector2(0, 32)  # 下边相邻格子
	
	# 创建第二个门
	var second_door = entry.object_scene.instantiate()
	if second_door is Node2D:
		second_door.global_position = second_position
		add_child(second_door)
		
		# 设置第二个门的ID
		_set_door_id(second_door, door_id)
		
		# 保存第二个门的信息
		var object_data_second = {
			"object_name": entry.object_name,
			"object_scene": entry.object_scene,
			"position": second_position,
			"instance": second_door,
			"door_id": door_id
		}
		objects.append(object_data_second)
		
		print("[%s] 放置配对门，ID: " % Time.get_time_string_from_system(), door_id, " 位置: ", second_position)

# 设置门的ID
func _set_door_id(door_node: Node2D, door_id: int):
	# 检查是否是Spawner类型（通过class_name或property_exists）
	if door_node is Spawner or door_node.has_meta("spawn_object_scene"):
		# Spawner类型，在Spawner上存储door_id
		door_node.set_meta("door_id", door_id)
		# 根据door_id设置Suit节点的texture
		_update_door_suit_texture(door_node, door_id)
		return
	
	# 直接获取Area2D/DoorComponent并设置
	var door_component = door_node.get_node_or_null("Area2D/DoorComponent")
	if door_component and door_component.has_method("set_door_id"):
		door_component.set_door_id(door_id)

# 获取当前已放置的门数量
func _get_door_count() -> int:
	var count = 0
	for object_data in objects:
		if object_data.get("object_name") == "door":
			count += 1
	return count

# 根据door_id设置Suit节点的texture
func _update_door_suit_texture(door_node: Node2D, door_id: int):
	print("[%s] _update_door_suit_texture: door_node=%s, door_id=%d" % [Time.get_time_string_from_system(), door_node.name, door_id])
	
	# 获取Suit节点
	var suit_node = door_node.get_node_or_null("Suit")
	print("[%s] Suit节点: %s" % [Time.get_time_string_from_system(), suit_node])
	
	if not suit_node:
		print("[%s] 警告：找不到Suit节点" % Time.get_time_string_from_system())
		return
	
	if not suit_node.has_method("set_texture"):
		print("[%s] 警告：Suit节点没有set_texture方法" % Time.get_time_string_from_system())
		return
	
	# 从Spawner的sprites数组中获取纹理
	var sprites_array = door_node.get("sprites")
	if sprites_array == null:
		sprites_array = []
	print("[%s] sprites数组: %s, 长度: %d" % [Time.get_time_string_from_system(), sprites_array, len(sprites_array)])
	
	if len(sprites_array) == 0:
		print("[%s] 警告：sprites数组为空" % Time.get_time_string_from_system())
		return
	
	# 根据door_id选择花色（1-4对应四种花色）
	var suit_index = (door_id - 1) % len(sprites_array)
	print("[%s] 花色索引: %d" % [Time.get_time_string_from_system(), suit_index])
	
	var texture = sprites_array[suit_index]
	print("[%s] 纹理: %s" % [Time.get_time_string_from_system(), texture])
	
	if texture:
		suit_node.texture = texture
		print("[%s] 设置门花色成功" % Time.get_time_string_from_system())
	else:
		print("[%s] 警告：纹理为空" % Time.get_time_string_from_system())

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
		
		# 如果是门对象，需要同时删除配对门
		if object_to_remove.has("object_name") and object_to_remove["object_name"] == "door":
			_remove_paired_doors(object_to_remove)
		else:
			if object_to_remove.has("instance") and is_instance_valid(object_to_remove["instance"]):
				object_to_remove["instance"].queue_free()
			objects.erase(object_to_remove)
		
		print("[%s] 橡皮擦：清除对象在位置 " % Time.get_time_string_from_system(), grid_position)
		return true
	
	#print("橡皮擦：位置 ", grid_position, " 没有对象")
	return false

# 删除配对门
func _remove_paired_doors(object_to_remove: Dictionary):
	var door_id = object_to_remove.get("door_id", -1)
	
	# 如果没有door_id，尝试从实例获取
	if door_id == -1 and object_to_remove.has("instance"):
		door_id = _get_door_id(object_to_remove["instance"])
	
	if door_id != -1:
		# 找到所有属于同一组（相同door_id）的门并删除
		var doors_to_remove = []
		for object_data in objects:
			if object_data.get("door_id", -1) == door_id:
				doors_to_remove.append(object_data)
		
		for door_data in doors_to_remove:
			if door_data.has("instance") and is_instance_valid(door_data["instance"]):
				door_data["instance"].queue_free()
			objects.erase(door_data)
		
		print("[%s] 橡皮擦：删除配对门，ID: " % Time.get_time_string_from_system(), door_id, " 共删除 ", doors_to_remove.size(), " 个")
	else:
		# 没有找到door_id，只删除当前门
		if object_to_remove.has("instance") and is_instance_valid(object_to_remove["instance"]):
			object_to_remove["instance"].queue_free()
		objects.erase(object_to_remove)

# 获取门的ID
func _get_door_id(door_node: Node2D) -> int:
	var door_component = door_node.get_node_or_null("Area2D/DoorComponent") as Node
	if door_component and door_component.has("id"):
		return door_component.get("id")
	return -1

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
		# 如果是门，保存门的ID
		if object_data["object_name"] == "door" and object_data.has("door_id"):
			save_object["door_id"] = object_data["door_id"]
		save_data.append(save_object)
	return save_data

# 加载对象数据（用于关卡加载）
func load_object_data(object_data: Array):
	clear_all_objects()
	_door_id_counter = 0  # 重置门ID计数器
	
	for save_object in object_data:
		var object_name = save_object["object_name"]
		var obj_position = Vector2(save_object["position"]["x"], save_object["position"]["y"])
		
		# 在数据库中查找对应的对象
		if database_holder and database_holder.object_database:
			current_object_name = object_name
			
			# 如果是门，直接加载（不再成对创建）
			if object_name == "door" and save_object.has("door_id"):
				_load_single_door(obj_position, save_object["door_id"])
			else:
				place_object_at_position(obj_position, true)

# 加载单个门（直接加载，不创建配对）
func _load_single_door(door_position: Vector2, door_id: int):
	var entry = find_object_by_name("door")
	if not entry or not entry.object_scene:
		return
	
	var door = entry.object_scene.instantiate()
	if door is Node2D:
		door.global_position = door_position
		add_child(door)
		_set_door_id(door, door_id)
		
		var object_data = {
			"object_name": "door",
			"object_scene": entry.object_scene,
			"position": door_position,
			"instance": door,
			"door_id": door_id
		}
		objects.append(object_data)
	
	# 更新门ID计数器
	if door_id > _door_id_counter:
		_door_id_counter = door_id
