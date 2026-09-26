extends Node

@export var path_to_tile_map_layer: NodePath = ".."
@export var semi_solid_scene: PackedScene = preload("uid://b46odv7so3u8a")

var tile_map: TileMapLayer

func _ready() -> void:
	tile_map = get_node(path_to_tile_map_layer) as TileMapLayer
	var fc: Callable = func() -> void:
		# 获取TileSet的CustomData层索引
		var tile_set: TileSet = tile_map.tile_set
		if tile_set == null:
			return
		
		# 查找semi-solid CustomData层的索引
		var semi_solid_layer_index: int = -1
		for i: int in range(tile_set.get_custom_data_layers_count()):
			if tile_set.get_custom_data_layer_name(i) == "semi-solid":
				semi_solid_layer_index = i
				break
		
		if semi_solid_layer_index == -1:
			return
		
		# 获取所有有瓦片的单元格坐标
		var used_cells: Array[Vector2i] = tile_map.get_used_cells()
		
		# 遍历所有有瓦片的单元格，检查CustomData
		for cell_coords: Vector2i in used_cells:
			var tile_data: TileData = tile_map.get_cell_tile_data(cell_coords)
			if tile_data != null:
				var is_semi_solid: Variant = tile_data.get_custom_data("semi-solid")
				if is_semi_solid:
					var semi_solid: Node2D = semi_solid_scene.instantiate()
					semi_solid.position = tile_map.map_to_local(cell_coords)
					tile_map.add_child(semi_solid)
	fc.call_deferred()