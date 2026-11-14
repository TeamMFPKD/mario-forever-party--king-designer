extends Node

@export var path_to_tile_map: NodePath = ".."
@export var sealer_scene: PackedScene

var tile_map: TileMapLayer
var level_camera: Camera2D

## 本节点创建出来的封顶实心，关卡重新加载时统一清理，避免重复叠加。
var _created: Array[Node2D] = []

func _ready() -> void:
	tile_map = get_node(path_to_tile_map) as TileMapLayer
	_connect_level_manager()
	# 场景自带瓦片（如测试房间）时先建一次；关卡文件稍后灌入时由信号重建。
	detect_level_ceiling.call_deferred()

## 关卡瓦片是在场景 ready 之后才写进 TileMapLayer 的：
## LevelManager.load_level 是延迟连接，_ready 时相机 limit 还是 Camera2D 默认值、
## 地图里也还没有关卡瓦片，只在 _ready 里扫一遍会一个 sealer 都建不出来。
## 因此要等关卡数据全部落地（相机 limit 已应用、瓦片已写入）后再扫描。
func _connect_level_manager() -> void:
	var manager: LevelManager = get_tree().get_first_node_in_group("level_manager") as LevelManager
	if manager == null:
		return
	if not manager.has_signal("level_data_loaded"):
		return
	if not manager.is_connected("level_data_loaded", _on_level_data_loaded):
		manager.connect("level_data_loaded", _on_level_data_loaded)

func _on_level_data_loaded() -> void:
	detect_level_ceiling()

func detect_level_ceiling() -> void:
	_clear_created()
	level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
	if not tile_map or not level_camera:
		push_error("SealerCreator: TileMap或LevelCamera未找到")
		return
	
	# 获取Camera的limit_top位置
	var camera_top: int = level_camera.limit_top
	
	# 获取TileMap的所有已使用单元格
	var used_cells: Array[Vector2i] = tile_map.get_used_cells()
	
	# 检测每个单元格是否在limit_top附近
	for cell: Vector2i in used_cells:
		# 获取该单元格的图集坐标
		var atlas_coords: Vector2i = tile_map.get_cell_atlas_coords(cell)
		
		# 检查图集坐标的y坐标是否大于3，如果是则跳过
		if atlas_coords.y > 3:
			continue
		
		# 将单元格坐标转换为世界坐标
		var cell_size: Vector2i = tile_map.tile_set.tile_size
		@warning_ignore("integer_division")
		var world_pos: Vector2 = Vector2(
			cell.x * cell_size.x + cell_size.x / 2,
			cell.y * cell_size.y + cell_size.y / 2
		)
		
		# 检查是否在limit_top ± 32px范围内
		if abs(world_pos.y - camera_top) <= 32:
			# 创建sealer
			create_sealer(world_pos)
			#print("SealerCreator: 在limit_top附近创建sealer，位置: ", world_pos, " 图集坐标: ", atlas_coords)

func create_sealer(create_pos: Vector2) -> void:
	if not sealer_scene:
		push_error("SealerCreator: Sealer场景未设置")
		return
	
	var sealer: Node2D = sealer_scene.instantiate() as Node2D
	if sealer:
		sealer.position = create_pos
		add_sibling(sealer)
		_created.append(sealer)
		#print("SealerCreator: Sealer创建成功，位置: ", create_pos)
	else:
		push_error("SealerCreator: Sealer实例化失败")

func _clear_created() -> void:
	for sealer: Node2D in _created:
		if is_instance_valid(sealer):
			sealer.queue_free()
	_created.clear()
