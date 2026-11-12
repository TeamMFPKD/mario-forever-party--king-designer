extends Node2D

class_name ObjectMapLayer

signal play_sound_drag

@export var objects: Array = []
@export var database_holder: DatabaseHolder
## 观看视图设为 false：不生成可操作的 player，也不创建 InputHandler。
@export var spawn_player: bool = true

# 输入处理相关变量
var is_placing: bool = false
var current_object_name: String = ""
var drawing_enabled: bool = false

# 门ID计数器（初始为0，这样第一组门的ID就是1）
var _door_id_counter: int = 0
# 最大门组数
const MAX_DOOR_GROUPS: int = 4
# 每组门数量
const DOORS_PER_GROUP: int = 2
# 粉币最大数量
const MAX_PINK_COINS: int = 10

# 拖动相关变量
var _dragging_object: Dictionary = {}
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_original_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

# 放置预览相关变量（仅桌面端：鼠标悬停时显示待放置物件的半透明预览）
# 移动端没有鼠标悬停，不创建预览。
const PREVIEW_ALPHA: float = 0.55
const PREVIEW_Z_INDEX: int = 10
const PREVIEW_MODULATE: Color = Color(1.0, 1.0, 1.0, PREVIEW_ALPHA)
const PREVIEW_NONE_GRID: Vector2 = Vector2(-99999.0, -99999.0)
# InputHandler 用这个坐标表示“事件不在游戏视口内”
const INVALID_INPUT_POSITION: Vector2 = Vector2(-9999.0, -9999.0)

var _input_handler: InputHandler = null
var _preview_root: Node2D = null
var _preview_nodes: Array[Node2D] = []
var _preview_grid_position: Vector2 = PREVIEW_NONE_GRID

func _ready() -> void:
	if not spawn_player:
		return
	# 确保有输入处理器
	setup_input_handler()

	# 祖传玩家位置
	var game_mode_node: GameMode = GameModeSingleton
	if game_mode_node.game_mode != GameMode.GameModeType.EDIT:
		return
	current_object_name = "player"
	if not database_holder or not database_holder.object_database or current_object_name == "":
		return
	
	# 查找对应的对象条目
	var entry: ObjectDatabaseEntry = find_object_by_name(current_object_name)
	if not entry or not entry.object_scene:
		Log.i("ObjectMapLayer", ["未找到对象: ", current_object_name])
		return
	
	# 如果是player对象，先删除所有已存在的player对象
	if current_object_name == "player":
		remove_all_objects_of_type("player")
		Log.i("ObjectMapLayer", "放置player前已清除所有已存在的player对象")
	
	# 将位置对齐到32x32网格
	var grid_position: Vector2 = align_to_grid(Vector2(112.0, 400.0))
	
	var scene_instance: Node = entry.object_scene.instantiate()
	if scene_instance is Node2D:
		var scene_2d: Node2D = scene_instance
		scene_2d.global_position = grid_position
		add_child(scene_instance)
		
		# 保存对象信息
		var object_data: Dictionary = {
			"object_name": entry.object_name,
			"object_scene": entry.object_scene,
			"position": grid_position,
			"instance": scene_instance
		}
		objects.append(object_data)

func setup_input_handler() -> void:
	# 检查是否已有输入处理器
	var input_handler: InputHandler = null
	
	# 首先尝试在场景树中查找InputHandler节点
	for child: Node in get_tree().root.get_children():
		if child is InputHandler:
			input_handler = child
			break
	
	if not input_handler:
		# 如果没有，创建并添加到当前节点的父节点中
		var input_handler_script: GDScript = preload("uid://devgf5ccfvhwv")
		input_handler = input_handler_script.new()
		input_handler.name = "InputHandler"
		get_parent().call_deferred("add_child", input_handler)
		# 等待一帧让InputHandler完全初始化
		await get_tree().process_frame
		Log.i("ObjectMapLayer", "InputHandler created and added to parent")
	
	# 重新获取InputHandler引用
	input_handler = null
	for child: Node in get_parent().get_children():
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
		_input_handler = input_handler
		Log.i("ObjectMapLayer", "InputHandler signals connected successfully")
	else:
		Log.i("ObjectMapLayer", "Error: Failed to find or create InputHandler")

# ---------------------------------------------------------------------------
# 放置预览（仅桌面端）
# 选中物件后，鼠标悬停处显示半透明预览，方便在落点前确认位置。
# 预览节点不参与放置/保存/碰撞，切换物件或退出放置模式后销毁。
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _preview_nodes.is_empty():
		return

	var game_mode_node: GameMode = GameModeSingleton
	if game_mode_node.game_mode != GameMode.GameModeType.EDIT:
		_set_preview_visible(false)
		return

	if not drawing_enabled or current_object_name == "" or _is_dragging:
		_set_preview_visible(false)
		return

	if not _is_pointer_inside_level_viewport():
		_set_preview_visible(false)
		return

	var hover_position: Vector2 = INVALID_INPUT_POSITION
	if _input_handler:
		hover_position = _input_handler.current_position
	if hover_position == INVALID_INPUT_POSITION:
		_set_preview_visible(false)
		return

	var grid_position: Vector2 = align_to_grid(hover_position)
	if grid_position != _preview_grid_position:
		_preview_grid_position = grid_position
		_update_preview_positions(grid_position)

	_set_preview_visible(true)

# 鼠标是否还在游戏视口内（视口外的坐标不会更新，避免预览停在边缘）
func _is_pointer_inside_level_viewport() -> bool:
	return InputHandler.is_pointer_inside_game_viewport(get_viewport())

# 按当前选中的物件创建预览实例（门会成对显示）
func _create_placement_preview(object_name: String) -> void:
	if not PlatformUtils.is_desktop_platform():
		return

	_clear_placement_preview()

	if object_name == "":
		return
	var entry: ObjectDatabaseEntry = find_object_by_name(object_name)
	if not entry or not entry.object_scene:
		return

	var preview_root: Node2D = _get_preview_root()
	var preview_count: int = 1
	if object_name == "door" or object_name == "door_locked":
		preview_count = 2

	for i: int in range(preview_count):
		var scene_instance: Node = entry.object_scene.instantiate()
		if not (scene_instance is Node2D):
			scene_instance.queue_free()
			continue
		var scene_2d: Node2D = scene_instance
		_disable_preview_interaction(scene_2d)
		preview_root.add_child(scene_2d)
		_preview_nodes.append(scene_2d)

	_preview_grid_position = PREVIEW_NONE_GRID
	preview_root.modulate = PREVIEW_MODULATE
	preview_root.visible = false

# 预览容器：抬高绘制层级，避免被已放置物件/地形遮住
func _get_preview_root() -> Node2D:
	if _preview_root != null and is_instance_valid(_preview_root):
		return _preview_root

	_preview_root = Node2D.new()
	_preview_root.name = "PlacementPreview"
	_preview_root.z_index = PREVIEW_Z_INDEX
	_preview_root.z_as_relative = false
	_preview_root.process_mode = Node.PROCESS_MODE_DISABLED
	# 鼠标跟随是逐帧瞬移，不能参与物理插值，否则会拖影/滞后
	_preview_root.physics_interpolation_mode = CanvasItem.PHYSICS_INTERPOLATION_MODE_OFF
	_preview_root.visible = false
	add_child(_preview_root)
	return _preview_root

# 销毁当前预览实例（只保留容器，下次选中物件时复用）
func _clear_placement_preview() -> void:
	for preview_node: Node2D in _preview_nodes:
		if is_instance_valid(preview_node):
			preview_node.visible = false
			preview_node.queue_free()
	_preview_nodes.clear()
	_preview_grid_position = PREVIEW_NONE_GRID

	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.visible = false

# 预览实例只做显示：停掉处理逻辑、禁用碰撞，避免影响编辑器
func _disable_preview_interaction(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED

	if node is CollisionObject2D:
		var collision_object: CollisionObject2D = node
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		if collision_object is Area2D:
			var area: Area2D = collision_object
			area.monitoring = false
			area.monitorable = false
	elif node is CollisionShape2D:
		var collision_shape: CollisionShape2D = node
		collision_shape.disabled = true

	for child: Node in node.get_children():
		_disable_preview_interaction(child)

# 把预览摆到网格位置（门会同时显示配对位置）
func _update_preview_positions(grid_position: Vector2) -> void:
	var preview_positions: Array[Vector2] = [grid_position]
	if current_object_name == "door" or current_object_name == "door_locked":
		preview_positions.append(_find_door_pair_position(grid_position))

	for i: int in range(_preview_nodes.size()):
		var preview_node: Node2D = _preview_nodes[i]
		if i < preview_positions.size():
			preview_node.global_position = preview_positions[i]
			preview_node.reset_physics_interpolation()
			preview_node.visible = true
		else:
			preview_node.visible = false

func _set_preview_visible(value: bool) -> void:
	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.visible = value

func _update_drag(world_pos: Vector2) -> void:
	if not _is_dragging or _dragging_object.is_empty():
		return
	
	var new_grid_pos: Vector2 = align_to_grid(world_pos)
	var current_pos: Vector2 = _dragging_object.get("position", Vector2.ZERO)
	
	if new_grid_pos == current_pos:
		return
	
	for object_data: Dictionary in objects:
		if object_data == _dragging_object:
			continue
		if object_data.has("position") and object_data["position"] == new_grid_pos:
			Log.i("ObjectMapLayer", "拖动被阻止：目标位置已有对象")
			return
	
	var instance: Node2D = _dragging_object.get("instance")
	if instance and is_instance_valid(instance):
		instance.global_position = new_grid_pos
		_dragging_object["position"] = new_grid_pos
		Log.i("ObjectMapLayer", ["拖动更新位置: ", current_pos, " -> ", new_grid_pos])
		emit_signal("play_sound_drag")

func _finish_drag() -> void:
	if not _is_dragging:
		return
	
	_is_dragging = false
	
	if _dragging_object.is_empty():
		return
	
	var new_pos: Vector2 = _dragging_object.get("position", _drag_original_pos)
	var object_name: String = _dragging_object.get("object_name", "")
	var door_id: int = _get_door_id_from_data(_dragging_object)
	
	# 拖动过程中只做实时预览，松手时把整段位移合并成一条命令。
	if object_name != "" and new_pos != _drag_original_pos:
		var command: CmdMoveObject = CmdMoveObject.create(self, object_name, door_id, _drag_original_pos, new_pos)
		if command != null:
			_push_executed_command(command)
	
	if object_name == "door":
		_on_door_dragged(_dragging_object, new_pos)
	
	Log.i("ObjectMapLayer", ["拖动结束: ", object_name, " ", _drag_original_pos, " -> ", new_pos])
	_dragging_object = {}

func _on_door_dragged(door_data: Dictionary, _new_pos: Vector2) -> void:
	var door_id: int = door_data.get("door_id", -1)
	if door_id == -1:
		return
	
	for object_data: Dictionary in objects:
		if object_data.get("door_id", -1) == door_id and object_data != door_data:
			if object_data.has("instance") and is_instance_valid(object_data["instance"]):
				Log.i("ObjectMapLayer", "门拖动：同组门ID %d 位置更新" % [door_id])

func _on_input_clicked(input_pos: Vector2) -> void:
	var game_mode_node: GameMode = GameModeSingleton
	if game_mode_node.game_mode != GameMode.GameModeType.EDIT:
		return
	
	var grid_pos: Vector2 = align_to_grid(input_pos)
	
	for object_data: Dictionary in objects:
		if object_data.has("instance") and is_instance_valid(object_data["instance"]):
			var obj_pos: Vector2 = object_data["position"]
			if abs(obj_pos.x - grid_pos.x) < 16.0 and abs(obj_pos.y - grid_pos.y) < 16.0:
				_dragging_object = object_data
				_drag_start_pos = input_pos
				_drag_original_pos = object_data["position"]
				_is_dragging = true
				Log.i("ObjectMapLayer", ["开始拖动对象: ", object_data.get("object_name", "unknown"), " 位置: ", obj_pos])
				return
	
	if drawing_enabled and database_holder and database_holder.object_database and current_object_name != "":
		place_object_at_position(input_pos, true)

# 新增：处理拖拽事件
func _on_input_dragged(input_pos: Vector2) -> void:
	if _is_dragging:
		_update_drag(input_pos)
	elif drawing_enabled and database_holder and database_holder.object_database and current_object_name != "":
		var grid_position: Vector2 = align_to_grid(input_pos)
		if not is_grid_position_occupied(grid_position):
			place_object_at_position(input_pos, false)

func _on_input_released(_input_pos: Vector2) -> void:
	if _is_dragging:
		_finish_drag()
	is_placing = false

# 在指定位置放置对象（走命令，自动进入撤销栈）
func place_object_at_position(input_pos: Vector2, check_duplicate: bool = true) -> void:
	var command: CmdPlaceObject = _build_place_command(current_object_name, input_pos, check_duplicate)
	if command == null:
		return
	_execute_edit_command(command)
	emit_place_sound()

# 组装“放置”命令：只做合法性检查与数据推导，不创建节点
func _build_place_command(object_name: String, input_pos: Vector2, check_duplicate: bool) -> CmdPlaceObject:
	if not database_holder or not database_holder.object_database or object_name == "":
		return null
	
	var entry: ObjectDatabaseEntry = find_object_by_name(object_name)
	if not entry or not entry.object_scene:
		Log.i("ObjectMapLayer", ["未找到对象: ", object_name])
		return null
	
	var grid_position: Vector2 = align_to_grid(input_pos)
	
	if check_duplicate and is_grid_position_occupied(grid_position):
		Log.i("ObjectMapLayer", "该网格位置已有对象，不进行绘制")
		return null
	
	if object_name == "door" or object_name == "door_locked":
		if _get_door_count() >= MAX_DOOR_GROUPS * DOORS_PER_GROUP:
			Log.i("ObjectMapLayer", "已达到最大门数量限制 (%d个)" % [MAX_DOOR_GROUPS * DOORS_PER_GROUP])
			return null
	
	if object_name == "pink_coin":
		if _get_pink_coin_count() >= MAX_PINK_COINS:
			Log.i("ObjectMapLayer", "粉币数量已达上限")
			return null
	
	var entries: Array[Dictionary] = []
	if object_name == "door" or object_name == "door_locked":
		var door_id: int = _find_available_door_id()
		if door_id < 0:
			Log.e("ObjectMapLayer", "最多只能放置4组门！")
			return null
		var second_position: Vector2 = _find_door_pair_position(grid_position)
		entries.append({"object_name": object_name, "position": grid_position, "door_id": door_id})
		entries.append({"object_name": object_name, "position": second_position, "door_id": door_id})
		Log.i("ObjectMapLayer", "放置门组: ID=%d, 应使用花色%d" % [door_id, (door_id - 1) % 4 + 1])
	else:
		entries.append({"object_name": object_name, "position": grid_position})
	
	# 全局只允许一个 player：由命令记录“顶掉的旧 player”，撤销时恢复
	return CmdPlaceObject.create(self, entries, object_name == "player")

# 找一个未被占用的门组 ID
func _find_available_door_id() -> int:
	var used_ids: Array[int] = []
	for object_data: Dictionary in objects:
		var obj_name: String = object_data.get("object_name", "")
		if obj_name != "door" and obj_name != "door_locked":
			continue
		var id: int = _get_door_id_from_data(object_data)
		if id > 0 and id <= MAX_DOOR_GROUPS and id not in used_ids:
			used_ids.append(id)
	for candidate_id: int in range(1, MAX_DOOR_GROUPS + 1):
		if candidate_id not in used_ids:
			return candidate_id
	return -1

# 计算配对门的第二个位置（优先右、上、左、下）
func _find_door_pair_position(first_position: Vector2) -> Vector2:
	var offsets: Array[Vector2] = [Vector2(32, 0), Vector2(0, -32), Vector2(-32, 0), Vector2(0, 32)]
	var candidate: Vector2 = first_position + offsets[0]
	for offset: Vector2 in offsets:
		candidate = first_position + offset
		if not is_grid_position_occupied(candidate):
			return candidate
	return candidate

# 设置门的ID
func _set_door_id(door_node: Node2D, door_id: int) -> void:
	# 检查是否是Spawner类型（通过class_name或property_exists）
	if door_node is Spawner or door_node.has_meta("spawn_object_scene"):
		# Spawner类型，在Spawner上存储door_id
		door_node.set_meta("door_id", door_id)
		# 根据door_id设置Suit节点的texture
		_update_door_suit_texture(door_node, door_id)
		return
	
	# 直接获取Area2D/DoorComponent并设置
	var door_component: Node = door_node.get_node_or_null("Area2D/DoorComponent")
	if door_component and door_component.has_method("set_door_id"):
		door_component.call("set_door_id", door_id)

# 获取当前已放置的粉币数量
func _get_pink_coin_count() -> int:
	var count: int = 0
	for object_data: Dictionary in objects:
		if object_data.get("object_name", "") == "pink_coin":
			count += 1
	return count

# 获取当前已放置的门数量（包括door和door_locked）
func _get_door_count() -> int:
	var count: int = 0
	for object_data: Dictionary in objects:
		var obj_name: String = object_data.get("object_name", "")
		if obj_name == "door" or obj_name == "door_locked":
			count += 1
	return count

# 根据door_id设置Suit节点的texture
func _update_door_suit_texture(door_node: Node2D, door_id: int) -> void:
	Log.i("ObjectMapLayer", "_update_door_suit_texture: door_node=%s, door_id=%d" % [door_node.name, door_id])
	
	# 获取Suit节点
	var suit_node: Node = door_node.get_node_or_null("Suit")
	Log.i("ObjectMapLayer", "Suit节点: %s" % [suit_node])
	
	if not suit_node:
		Log.i("ObjectMapLayer", "警告：找不到Suit节点")
		return
	
	if not suit_node.has_method("set_texture"):
		Log.i("ObjectMapLayer", "警告：Suit节点没有set_texture方法")
		return
	
	# 从Spawner的sprites数组中获取纹理
	var sprites_array: Array = []
	if door_node.has_method("get_sprites"):
		sprites_array = door_node.call("get_sprites")
	elif "sprites" in door_node:
		sprites_array = door_node.get("sprites")
	Log.i("ObjectMapLayer", "sprites数组: %s, 长度: %d" % [sprites_array, len(sprites_array)])
	
	# 过滤掉null元素，获取有效的纹理列表
	var valid_textures: Array = []
	for tex: Variant in sprites_array:
		if tex != null:
			valid_textures.append(tex)
	
	if len(valid_textures) == 0:
		Log.i("ObjectMapLayer", "警告：没有有效的花色纹理")
		return
	
	# 根据door_id选择花色（1-4对应四种花色）
	var suit_index: int = (door_id - 1) % len(valid_textures)
	Log.i("ObjectMapLayer", "花色索引: %d (有效纹理数量: %d)" % [suit_index, len(valid_textures)])
	
	var texture: Variant = valid_textures[suit_index]
	Log.i("ObjectMapLayer", "纹理: %s" % [texture])
	
	if texture:
		suit_node.set("texture", texture)
		Log.i("ObjectMapLayer", "设置门花色成功")
	else:
		Log.i("ObjectMapLayer", "警告：纹理为空")

# 新增：发射放置音效的函数
func emit_place_sound() -> void:
	# 获取LevelControl节点并发射信号
	var level_node: LevelControl = get_tree().get_first_node_in_group("level_control")
	if is_instance_valid(level_node):
		level_node.emit_signal("play_sound_place")


# 公共方法：开始放置对象（通过对象名称）
func start_placing_object(object_name: String) -> void:
	if database_holder and database_holder.object_database:
		current_object_name = object_name
		is_placing = true
		drawing_enabled = true
		_create_placement_preview(object_name)
		Log.i("ObjectMapLayer", ["开始放置对象: ", object_name])

# 公共方法：停止放置对象
func stop_placing_object() -> void:
	is_placing = false
	drawing_enabled = false
	current_object_name = ""
	_clear_placement_preview()
	Log.i("ObjectMapLayer", "停止放置对象")

# 将位置对齐到32x32网格
func align_to_grid(input_pos: Vector2) -> Vector2:
	var grid_size: int = 32
	return Vector2(
		floorf(input_pos.x / grid_size) * grid_size + grid_size / 2.0,
		floorf(input_pos.y / grid_size) * grid_size + grid_size / 2.0
	)

# 检查网格位置是否已有对象
func is_grid_position_occupied(grid_position: Vector2) -> bool:
	for object_data: Dictionary in objects:
		if object_data.has("position") and object_data["position"] == grid_position:
			return true
	return false

# 通过对象名称查找对应的数据库条目
func find_object_by_name(object_name: String) -> ObjectDatabaseEntry:
	if not database_holder or not database_holder.object_database:
		return null
	
	for entry: ObjectDatabaseEntry in database_holder.object_database.object_database_entry:
		if entry and entry.object_name == object_name:
			return entry
	
	return null

# 移除指定位置的对象（走命令，自动进入撤销栈）
func remove_object_at_position(input_pos: Vector2) -> bool:
	var command: CmdRemoveObject = _build_remove_command(input_pos)
	if command == null:
		return false
	_execute_edit_command(command)
	Log.i("ObjectMapLayer", ["橡皮擦：清除对象在位置 ", align_to_grid(input_pos)])
	return true

# 组装“删除”命令：门按 door_id 成组删除
func _build_remove_command(input_pos: Vector2) -> CmdRemoveObject:
	var grid_position: Vector2 = align_to_grid(input_pos)
	var object_to_remove: Dictionary = find_record_at_grid(grid_position)
	if object_to_remove.is_empty():
		return null
	if object_to_remove.get("object_name", "") == "player":
		return null
	var obj_name: String = object_to_remove.get("object_name", "")
	var targets: Array[Dictionary] = []
	if obj_name == "door" or obj_name == "door_locked":
		targets = _collect_door_targets(object_to_remove)
	else:
		targets.append(describe_object(object_to_remove))
	if targets.is_empty():
		return null
	return CmdRemoveObject.create(self, targets)

# 收集同一 door_id 的所有门（成组删除）
func _collect_door_targets(door_data: Dictionary) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var door_id: int = _get_door_id_from_data(door_data)
	if door_id == -1 and door_data.has("instance"):
		var instance: Variant = door_data["instance"]
		if instance is Node2D:
			var door_node: Node2D = instance
			door_id = _get_door_id(door_node)
	if door_id == -1:
		targets.append(describe_object(door_data))
		return targets
	for object_data: Dictionary in objects:
		if _get_door_id_from_data(object_data) == door_id:
			targets.append(describe_object(object_data))
	Log.i("ObjectMapLayer", ["橡皮擦：删除配对门，ID: ", door_id, " 共删除 ", targets.size(), " 个"])
	return targets

# 获取门的ID
func _get_door_id(door_node: Node2D) -> int:
	var door_component: Node = door_node.get_node_or_null("Area2D/DoorComponent")
	if door_component is DoorComponent:
		var dc: DoorComponent = door_component
		return dc.id
	return -1

# 获取指定位置的对象
func get_object_at_position(input_pos: Vector2) -> Dictionary:
	var grid_position: Vector2 = align_to_grid(input_pos)
	for object_data: Dictionary in objects:
		if object_data.has("position") and object_data["position"] == grid_position:
			return object_data
	return {}

# 清空所有对象
func clear_all_objects() -> void:
	for object_data: Dictionary in objects:
		var inst: Node2D = object_data.get("instance")
		if object_data.has("instance") and is_instance_valid(inst):
			inst.queue_free()
	objects.clear()

# 删除特定类型的所有对象（供初始化 / 关卡加载使用，不写入撤销栈）
func remove_all_objects_of_type(object_name: String) -> void:
	var removed: Array[Dictionary] = despawn_objects_of_type(object_name)
	Log.i("ObjectMapLayer", ["已删除所有类型为 '", object_name, "' 的对象，共删除 ", removed.size(), " 个"])

# 保存对象数据（用于关卡保存）
func get_object_data() -> Array:
	var save_data: Array = []
	for object_data: Dictionary in objects:
		var save_object: Dictionary = {
			"object_name": object_data["object_name"],
			"position": {
				"x": object_data["position"].x,
				"y": object_data["position"].y
			}
		}
		# 如果是门，保存门的ID
		var obj_name: String = object_data["object_name"]
		if (obj_name == "door" or obj_name == "door_locked") and object_data.has("door_id"):
			save_object["door_id"] = object_data["door_id"]
		save_data.append(save_object)
	return save_data

# 加载对象数据（用于关卡加载）
func load_object_data(object_data: Array) -> void:
	clear_all_objects()
	_door_id_counter = 0  # 重置门ID计数器

	for save_object: Dictionary in object_data:
		var object_name: String = save_object["object_name"]
		if object_name == "player" and not spawn_player:
			continue
		var pos_dict: Dictionary = save_object["position"]
		var px: float = pos_dict["x"]
		var py: float = pos_dict["y"]
		var obj_position: Vector2 = Vector2(px, py)
		
		# 在数据库中查找对应的对象
		if database_holder and database_holder.object_database:
			current_object_name = object_name
			
			# 如果是门（door或door_locked），直接加载（不再成对创建）
			if (object_name == "door" or object_name == "door_locked") and save_object.has("door_id"):
				var saved_door_id: int = save_object["door_id"]
				_load_single_door(object_name, obj_position, saved_door_id)
			else:
				place_object_at_position(obj_position, true)

# 加载单个门（直接加载，不创建配对）
func _load_single_door(object_name: String, door_position: Vector2, door_id: int) -> void:
	var entry: ObjectDatabaseEntry = find_object_by_name(object_name)
	if not entry or not entry.object_scene:
		return
	
	var door: Node = entry.object_scene.instantiate()
	if door is Node2D:
		var door_2d: Node2D = door
		door_2d.global_position = door_position
		add_child(door)
		_set_door_id(door_2d, door_id)
		
		var object_data: Dictionary = {
			"object_name": object_name,
			"object_scene": entry.object_scene,
			"position": door_position,
			"instance": door,
			"door_id": door_id
		}
		objects.append(object_data)
		
		Log.i("ObjectMapLayer", "加载门: %s, ID: %d, 位置: %s" % [object_name, door_id, door_position])
	
	# 更新门ID计数器
	if door_id > _door_id_counter:
		_door_id_counter = door_id

# ---------------------------------------------------------------------------
# 命令模式原语：创建 / 删除 / 定位对象
# 这些方法只改数据，不写历史；历史由 Cmd* 命令类负责。
# ---------------------------------------------------------------------------

# 按描述批量重建对象（undo 用）
func spawn_objects(descriptions: Array) -> void:
	for description: Dictionary in descriptions:
		var object_name: String = description.get("object_name", "")
		var grid_position: Vector2 = description.get("position", Vector2.ZERO)
		spawn_object(object_name, grid_position, _get_door_id_from_data(description))

# 按名称 + 网格位置重建单个对象
func spawn_object(object_name: String, grid_position: Vector2, door_id: int = -1) -> Dictionary:
	var entry: ObjectDatabaseEntry = find_object_by_name(object_name)
	if not entry or not entry.object_scene:
		Log.e("ObjectMapLayer", ["无法重建对象: ", object_name])
		return {}
	
	var scene_instance: Node = entry.object_scene.instantiate()
	if not (scene_instance is Node2D):
		scene_instance.queue_free()
		return {}
	
	var scene_2d: Node2D = scene_instance
	scene_2d.global_position = grid_position
	add_child(scene_instance)
	
	var object_data: Dictionary = {
		"object_name": object_name,
		"object_scene": entry.object_scene,
		"position": grid_position,
		"instance": scene_instance
	}
	if door_id >= 0:
		object_data["door_id"] = door_id
		_set_door_id(scene_2d, door_id)
	objects.append(object_data)
	return object_data

# 按描述批量删除，返回被删对象的描述（供 undo 恢复）
func despawn_objects(descriptions: Array) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	for description: Dictionary in descriptions:
		var object_data: Dictionary = find_object_record(description)
		if object_data.is_empty():
			continue
		removed.append(describe_object(object_data))
		despawn_record(object_data)
	return removed

# 按类型批量删除，返回被删对象的描述
func despawn_objects_of_type(object_name: String) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	for object_data: Dictionary in objects.duplicate():
		if object_data.get("object_name", "") == object_name:
			removed.append(describe_object(object_data))
			despawn_record(object_data)
	return removed

# 删除单个对象数据 + 节点
func despawn_record(object_data: Dictionary) -> void:
	if object_data.is_empty():
		return
	var instance: Variant = object_data.get("instance")
	if instance is Node and is_instance_valid(instance):
		var instance_node: Node = instance
		instance_node.queue_free()
	objects.erase(object_data)

# 从对象数据提取可持久保存的描述（不含节点引用）
func describe_object(object_data: Dictionary) -> Dictionary:
	var description: Dictionary = {
		"object_name": object_data.get("object_name", ""),
		"position": object_data.get("position", Vector2.ZERO)
	}
	var door_id: int = _get_door_id_from_data(object_data)
	if door_id >= 0:
		description["door_id"] = door_id
	return description

# 按描述定位对象数据
func find_object_record(description: Dictionary) -> Dictionary:
	var target_name: String = description.get("object_name", "")
	var target_position: Vector2 = description.get("position", Vector2.ZERO)
	var target_door_id: int = _get_door_id_from_data(description)
	for object_data: Dictionary in objects:
		if object_data.get("object_name", "") != target_name:
			continue
		if object_data.get("position", Vector2.ZERO) != target_position:
			continue
		if target_door_id >= 0 and _get_door_id_from_data(object_data) != target_door_id:
			continue
		return object_data
	return {}

# 按网格坐标定位对象数据
func find_record_at_grid(grid_position: Vector2) -> Dictionary:
	for object_data: Dictionary in objects:
		if object_data.get("position", Vector2.ZERO) == grid_position:
			return object_data
	return {}

# 设置对象网格位置（同时移动节点）
func set_record_position(object_data: Dictionary, grid_position: Vector2) -> void:
	object_data["position"] = grid_position
	var instance: Variant = object_data.get("instance")
	if instance is Node2D and is_instance_valid(instance):
		var instance_2d: Node2D = instance
		instance_2d.global_position = grid_position

# 按描述把对象从 from_position 移动到 to_position（命令 undo/redo 用）
func move_object_by_description(object_name: String, door_id: int, from_position: Vector2, to_position: Vector2) -> bool:
	var description: Dictionary = {
		"object_name": object_name,
		"position": from_position
	}
	if door_id >= 0:
		description["door_id"] = door_id
	var object_data: Dictionary = find_object_record(description)
	if object_data.is_empty():
		Log.e("ObjectMapLayer", ["移动失败，找不到对象: ", object_name, " @ ", from_position])
		return false
	set_record_position(object_data, to_position)
	return true

func _get_door_id_from_data(object_data: Dictionary) -> int:
	if not object_data.has("door_id"):
		return -1
	var raw_id: Variant = object_data["door_id"]
	if raw_id is int:
		var raw_int: int = raw_id
		return raw_int
	if raw_id is float:
		var raw_float: float = raw_id
		return int(raw_float)
	return -1

func _execute_edit_command(command: Command) -> void:
	var stack: CommandStack = CommandStack.find_in(get_tree())
	if stack != null:
		stack.execute_command(command)
	else:
		command.execute()

func _push_executed_command(command: Command) -> void:
	var stack: CommandStack = CommandStack.find_in(get_tree())
	if stack != null:
		stack.push_executed_command(command)
