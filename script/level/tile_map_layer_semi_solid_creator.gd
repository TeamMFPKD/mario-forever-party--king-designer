extends Node

@export var path_to_tile_map_layer: NodePath = ".."
@export var semi_solid_scene: PackedScene = preload("uid://b46odv7so3u8a")

var tile_map: TileMapLayer

func _ready() -> void:
	tile_map = get_node(path_to_tile_map_layer) as TileMapLayer
	var fc = func():
		# 获取TileSet的CustomData层索引
		var tile_set = tile_map.tile_set
		if tile_set == null:
			return
		
		# 查找semi-solid CustomData层的索引
		var semi_solid_layer_index = -1
		for i in range(tile_set.get_custom_data_layers_count()):
			if tile_set.get_custom_data_layer_name(i) == "semi-solid":
				semi_solid_layer_index = i
				break
		
		if semi_solid_layer_index == -1:
			return
		
		# 获取所有有瓦片的单元格坐标
		var used_cells = tile_map.get_used_cells()
		
		# 遍历所有有瓦片的单元格，检查CustomData
		for cell_coords in used_cells:
			var tile_data = tile_map.get_cell_tile_data(cell_coords)
			if tile_data != null:
				var is_semi_solid = tile_data.get_custom_data("semi-solid")
				if is_semi_solid:
					var semi_solid = semi_solid_scene.instantiate() as Node2D
					semi_solid.position = tile_map.map_to_local(cell_coords)
					tile_map.add_child(semi_solid)
	fc.call_deferred()