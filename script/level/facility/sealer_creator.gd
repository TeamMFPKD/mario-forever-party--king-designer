extends Node

@export var path_to_tile_map: NodePath = ".."
@export var sealer_scene: PackedScene

var tile_map: TileMapLayer
var level_camera: Camera2D

func _ready() -> void:
	tile_map = get_node(path_to_tile_map)
	var fc = func():
		level_camera = get_tree().get_first_node_in_group("level_camera") as Camera2D
		detect_level_ceiling()
	fc.call_deferred()

func detect_level_ceiling() -> void:
	if not tile_map or not level_camera:
		push_error("SealerCreator: TileMap或LevelCamera未找到")
		return
	
	# 获取Camera的limit_top位置
	var camera_top = level_camera.limit_top
	
	# 获取TileMap的所有已使用单元格
	var used_cells = tile_map.get_used_cells()
	
	# 检测每个单元格是否在limit_top附近
	for cell in used_cells:
		# 获取该单元格的图集坐标
		var atlas_coords = tile_map.get_cell_atlas_coords(cell)
		
		# 检查图集坐标的y坐标是否大于3，如果是则跳过
		if atlas_coords.y > 3:
			continue
		
		# 将单元格坐标转换为世界坐标
		var cell_size = tile_map.tile_set.tile_size
		var world_pos = Vector2(
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
	
	var sealer = sealer_scene.instantiate() as Node2D
	if sealer:
		sealer.position = create_pos
		add_sibling(sealer)
		#print("SealerCreator: Sealer创建成功，位置: ", create_pos)
	else:
		push_error("SealerCreator: Sealer实例化失败")